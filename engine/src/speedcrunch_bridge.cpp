// speedcrunch_bridge.cpp — C bridge over the SpeedCrunch engine (Qt Core only).
//
// The evaluation and rendering flow mirrors the desktop app:
//   * Enter  -> MainWindow::evaluateEditorExpression (gui/mainwindow.cpp)
//   * Typing -> Editor::autoCalc                      (gui/editor.cpp)
//
// Licensed under the GNU General Public License, version 2 or later.

#include "speedcrunch_bridge.h"

#include "core/constants.h"
#include "core/evaluator.h"
#include "core/functions.h"
#include "core/numberformatter.h"
#include "core/session.h"
#include "core/sessionhistory.h"
#include "core/settings.h"
#include "core/userfunction.h"
#include "core/variable.h"
#include "gui/resultlineformatutils.h"
#include "math/cmath.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>

#include <cstdlib>
#include <cstring>
#include <memory>

struct SCEngine {
    std::unique_ptr<Session> session;
    Evaluator* evaluator = nullptr;
    Settings* settings = nullptr;
    QString dataDir;
};

namespace {

const char* kSessionFile = "session.json";
const char* kSettingsFile = "settings.json";

// Qt needs an application object for paths and translations. Created once,
// never run (Swift owns the run loop).
void ensureCoreApplication()
{
    if (QCoreApplication::instance())
        return;
    static int argc = 1;
    static char appName[] = "SpeedCrunch";
    static char* argv[] = {appName, nullptr};
    QCoreApplication::setApplicationName(QStringLiteral("SpeedCrunch"));
    QCoreApplication::setOrganizationName(QStringLiteral("SpeedCrunch"));
    new QCoreApplication(argc, argv); // Intentionally leaked; lives for the process.
}

char* toCString(const QByteArray& bytes)
{
    char* out = static_cast<char*>(std::malloc(bytes.size() + 1));
    if (!out)
        return nullptr;
    std::memcpy(out, bytes.constData(), bytes.size());
    out[bytes.size()] = '\0';
    return out;
}

char* toJson(const QJsonObject& object)
{
    return toCString(QJsonDocument(object).toJson(QJsonDocument::Compact));
}

char* toJson(const QJsonArray& array)
{
    return toCString(QJsonDocument(array).toJson(QJsonDocument::Compact));
}

QString fromUtf8(const char* text)
{
    return text ? QString::fromUtf8(text) : QString();
}

// Function usage strings use <sub>n</sub> for argument indices; render them
// as Unicode subscript digits (x<sub>1</sub> -> x₁) before stripping tags.
QString subscriptsToUnicode(QString text)
{
    static const QRegularExpression sub(QStringLiteral("<sub>([^<]*)</sub>"));
    static const QString digits = QString::fromUtf8("₀₁₂₃₄₅₆₇₈₉");
    QRegularExpressionMatch match;
    while ((match = sub.match(text)).hasMatch()) {
        QString converted;
        for (const QChar ch : match.captured(1))
            converted += ch.isDigit() ? digits.at(ch.digitValue()) : ch;
        text.replace(match.capturedStart(), match.capturedLength(), converted);
    }
    return text;
}

// The evaluator formats errors as rich text for desktop tooltips
// ("<b>foo</b>: unknown function or variable"). Swift wants plain text.
QString plainText(QString html)
{
    static const QRegularExpression tags(QStringLiteral("<[^>]*>"));
    html.remove(tags);
    html.replace(QStringLiteral("&lt;"), QStringLiteral("<"));
    html.replace(QStringLiteral("&gt;"), QStringLiteral(">"));
    html.replace(QStringLiteral("&quot;"), QStringLiteral("\""));
    html.replace(QStringLiteral("&amp;"), QStringLiteral("&"));
    return html;
}

QJsonArray toJsonArray(const QStringList& list)
{
    QJsonArray array;
    for (const QString& item : list)
        array.append(item);
    return array;
}

EvaluationContext currentEvaluationContext(const Settings* settings)
{
    EvaluationContext ctx;
    ctx.main.fmt = settings->resultFormat;
    ctx.main.prec = settings->resultPrecision;
    ctx.main.cplx = settings->resultComplexForm;
    ctx.complexOn = settings->complexNumbers;
    ctx.unit = settings->imaginaryUnit;
    ctx.angle = settings->angleUnit;
    ctx.unitExp = settings->unitNegativeExponentStyle;
    ctx.round = settings->resultRoundingMode;
    return ctx;
}

// Pushes Settings values into the engine's runtime globals.
void applyRuntimeSettings(Settings* settings)
{
    settings->multipleResultLinesEnabled = false;
    settings->applyNumberFormatStyle();
    DMath::complexMode = settings->complexNumbers;
    CMath::setImaginaryUnitSymbol(settings->imaginaryUnit);
    setRuntimeUnitNegativeExponentStyle(settings->unitNegativeExponentStyle);
    setRuntimeResultRoundingMode(settings->resultRoundingMode);
}

QStringList renderedLines(const QString& expr, const QString& interpretedExpr,
                          const Quantity& result, const Evaluator* evaluator)
{
    QStringList lines;
    lines.append(ResultLineFormatUtils::formattedExpressionLineForDisplay(expr, interpretedExpr, evaluator));
    if (!result.isNan())
        lines.append(ResultLineFormatUtils::formatResultLinesForDisplay(
            expr, interpretedExpr, result, false, true, evaluator));
    return lines;
}

QJsonObject settingsToJson(const Settings* settings)
{
    QJsonObject json;
    json["angleUnit"] = QString(QChar(settings->angleUnit));
    json["resultFormat"] = QString(QChar(settings->resultFormat));
    json["precision"] = settings->resultPrecision;
    json["complexNumbers"] = settings->complexNumbers;
    json["decimalSeparator"] = QString(QChar(settings->decimalSeparator()));
    json["digitGrouping"] = !settings->digitGroupingSeparator().isEmpty();
    return json;
}

bool isOneOf(const QString& value, const char* allowed)
{
    return value.size() == 1 && std::strchr(allowed, value.at(0).toLatin1()) != nullptr;
}

void applySettingsJson(Settings* settings, const QJsonObject& json)
{
    const QString angle = json.value("angleUnit").toString();
    if (isOneOf(angle, "rdgtv"))
        settings->angleUnit = angle.at(0).toLatin1();

    const QString format = json.value("resultFormat").toString();
    if (isOneOf(format, "gfnerbohs"))
        settings->resultFormat = format.at(0).toLatin1();

    if (json.contains("precision")) {
        const int precision = json.value("precision").toInt(-1);
        settings->resultPrecision = (precision < 0) ? -1 : qMin(precision, 50);
    }

    if (json.contains("complexNumbers"))
        settings->complexNumbers = json.value("complexNumbers").toBool();

    if (json.contains("decimalSeparator") || json.contains("digitGrouping")) {
        const bool comma = json.contains("decimalSeparator")
            ? json.value("decimalSeparator").toString() == QLatin1String(",")
            : settings->decimalSeparator() == ',';
        const bool grouping = json.contains("digitGrouping")
            ? json.value("digitGrouping").toBool()
            : !settings->digitGroupingSeparator().isEmpty();
        if (comma)
            settings->numberFormatStyle = grouping ? Settings::NumberFormatThreeDigitDotComma
                                                   : Settings::NumberFormatNoGroupingComma;
        else
            settings->numberFormatStyle = grouping ? Settings::NumberFormatThreeDigitCommaDot
                                                   : Settings::NumberFormatNoGroupingDot;
    }

    applyRuntimeSettings(settings);
}

QJsonObject readJsonFile(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return QJsonObject();
    return QJsonDocument::fromJson(file.readAll()).object();
}

void writeJsonFile(const QString& path, const QJsonObject& json)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(json).toJson(QJsonDocument::Indented));
    file.commit();
}

} // namespace

extern "C" {

SCEngine* sc_engine_create(const char* data_dir)
{
    ensureCoreApplication();

    auto* engine = new SCEngine;
    engine->dataDir = fromUtf8(data_dir);
    engine->settings = Settings::instance();

    // Defaults suited to a phone; the stored settings file overrides them.
    engine->settings->angleUnit = 'r';
    engine->settings->resultFormat = 'g';
    engine->settings->resultPrecision = -1;
    engine->settings->complexNumbers = false;
    engine->settings->imaginaryUnit = 'i';
    engine->settings->numberFormatStyle = Settings::NumberFormatNoGroupingDot;
    applyRuntimeSettings(engine->settings);

    if (!engine->dataDir.isEmpty()) {
        QDir().mkpath(engine->dataDir);
        applySettingsJson(engine->settings,
                          readJsonFile(QDir(engine->dataDir).filePath(kSettingsFile)));
    }

    engine->session = std::make_unique<Session>();
    engine->evaluator = engine->session->evaluator();
    engine->evaluator->initializeBuiltInVariables();

    if (!engine->dataDir.isEmpty()) {
        const QJsonObject json = readJsonFile(QDir(engine->dataDir).filePath(kSessionFile));
        if (!json.isEmpty())
            engine->session->deSerialize(json, false);
    }

    return engine;
}

void sc_engine_destroy(SCEngine* engine)
{
    if (!engine)
        return;
    sc_engine_save(engine);
    delete engine;
}

char* sc_engine_evaluate(SCEngine* engine, const char* expression)
{
    QJsonObject out;
    if (!engine) {
        out["ok"] = false;
        out["error"] = QStringLiteral("Engine not initialized");
        return toJson(out);
    }

    Evaluator* eval = engine->evaluator;
    const QString entered = fromUtf8(expression);
    const QString expr = eval->autoFix(entered);
    const bool isCommentOnly = Evaluator::isCommentOnlyExpression(expr);

    if (expr.isEmpty()) {
        out["ok"] = false;
        out["error"] = QString();
        return toJson(out);
    }

    const EvaluationContext ctx = currentEvaluationContext(engine->settings);
    eval->setExpression(expr);
    Quantity result = eval->evalUpdateAns();

    if (!eval->error().isEmpty()) {
        out["ok"] = false;
        out["error"] = plainText(eval->error());
        return toJson(out);
    }

    QString kind = QStringLiteral("value");
    if (eval->isUserFunctionAssign()) {
        result = CMath::nan();
        kind = QStringLiteral("function");
    } else if (eval->isUserUnitAssign()) {
        result = CMath::nan();
        kind = QStringLiteral("unit");
    } else if (isCommentOnly) {
        kind = QStringLiteral("comment");
    } else if (result.isNan()) {
        out["ok"] = false;
        out["error"] = QString();
        return toJson(out);
    } else if (eval->isUserVariableAssign()) {
        kind = QStringLiteral("assign");
    }

    const QString interpreted = eval->interpretedExpression();
    HistoryEntry entry(entered, result, interpreted, ctx);
    const QStringList lines = renderedLines(entered, interpreted, result, eval);
    entry.setRenderedLines(lines);
    engine->session->addHistoryEntry(entry);
    sc_engine_save(engine);

    out["ok"] = true;
    out["kind"] = kind;
    out["expression"] = lines.value(0);
    out["lines"] = toJsonArray(lines.mid(1));
    return toJson(out);
}

char* sc_engine_preview(SCEngine* engine, const char* expression)
{
    QJsonObject out;
    out["ok"] = false;
    out["error"] = QString();
    if (!engine)
        return toJson(out);

    Evaluator* eval = engine->evaluator;
    const QString expr = eval->autoFix(fromUtf8(expression));
    if (expr.isEmpty())
        return toJson(out);

    // Same as Editor::autoCalc: never update "ans" or assign while previewing.
    eval->setExpression(expr);
    const Quantity quantity = eval->evalNoAssign();

    if (!eval->error().isEmpty()) {
        out["error"] = plainText(eval->error());
        return toJson(out);
    }
    if (quantity.isNan()
            && (eval->isUserFunctionAssign() || Evaluator::isCommentOnlyExpression(expr)))
        return toJson(out);
    if (quantity.isNan())
        return toJson(out);

    const QString interpreted = eval->interpretedExpression();
    const QStringList lines = ResultLineFormatUtils::formatResultLinesForDisplay(
        expr, interpreted, quantity, false, true, eval, true);
    out["ok"] = true;
    out["lines"] = toJsonArray(lines);
    out.remove("error");
    return toJson(out);
}

char* sc_engine_history(SCEngine* engine)
{
    QJsonArray array;
    if (!engine)
        return toJson(array);

    const int count = engine->session->historySize();
    for (int i = 0; i < count; ++i) {
        const HistoryEntry& entry = engine->session->historyEntryAtRef(i);
        QStringList lines = entry.renderedLines();
        if (lines.isEmpty())
            lines = renderedLines(entry.expr(), entry.interpretedExpr(), entry.result(),
                                  engine->evaluator);
        QJsonObject item;
        item["source"] = entry.expr();
        item["expression"] = lines.value(0);
        item["lines"] = toJsonArray(lines.mid(1));
        array.append(item);
    }
    return toJson(array);
}

void sc_engine_clear_history(SCEngine* engine)
{
    if (!engine)
        return;
    engine->session->clearHistory();
    sc_engine_save(engine);
}

void sc_engine_remove_history_entry(SCEngine* engine, int index)
{
    if (!engine || index < 0 || index >= engine->session->historySize())
        return;
    engine->session->removeHistoryEntryAt(index);
    sc_engine_save(engine);
}

char* sc_engine_variables(SCEngine* engine)
{
    QJsonArray array;
    if (!engine)
        return toJson(array);

    for (const Variable& variable : engine->evaluator->getUserDefinedVariablesPlusAns()) {
        QJsonObject item;
        item["name"] = variable.identifier();
        item["value"] = NumberFormatter::format(variable.value());
        array.append(item);
    }
    return toJson(array);
}

void sc_engine_remove_variable(SCEngine* engine, const char* name)
{
    if (!engine || !name)
        return;
    const QString identifier = fromUtf8(name);
    if (engine->evaluator->isBuiltInVariable(identifier))
        return;
    engine->evaluator->unsetVariable(identifier);
    sc_engine_save(engine);
}

char* sc_engine_user_functions(SCEngine* engine)
{
    QJsonArray array;
    if (!engine)
        return toJson(array);

    for (const UserFunction& function : engine->evaluator->getUserFunctions()) {
        QJsonObject item;
        item["name"] = function.name();
        item["arguments"] = toJsonArray(function.arguments());
        item["body"] = function.expression();
        array.append(item);
    }
    return toJson(array);
}

void sc_engine_remove_user_function(SCEngine* engine, const char* name)
{
    if (!engine || !name)
        return;
    engine->evaluator->unsetUserFunction(fromUtf8(name));
    sc_engine_save(engine);
}

char* sc_engine_builtin_functions(SCEngine* engine)
{
    Q_UNUSED(engine);
    QJsonArray array;
    FunctionRepo* repo = FunctionRepo::instance();
    QStringList identifiers = repo->getIdentifiers();
    identifiers.sort(Qt::CaseInsensitive);
    for (const QString& identifier : identifiers) {
        const Function* function = repo->find(identifier);
        if (!function)
            continue;
        QJsonObject item;
        item["identifier"] = function->identifier();
        item["name"] = function->name();
        item["usage"] = plainText(subscriptsToUnicode(function->usage()));
        array.append(item);
    }
    return toJson(array);
}

char* sc_engine_constants(SCEngine* engine)
{
    Q_UNUSED(engine);
    QJsonArray array;
    for (const Constant& constant : Constants::instance()->list()) {
        QJsonObject item;
        item["name"] = constant.name;
        item["value"] = constant.value;
        item["unit"] = constant.unit;
        item["domain"] = constant.domain;
        item["subdomain"] = constant.subdomain;
        array.append(item);
    }
    return toJson(array);
}

char* sc_engine_get_settings(SCEngine* engine)
{
    if (!engine)
        return toJson(QJsonObject());
    return toJson(settingsToJson(engine->settings));
}

void sc_engine_set_settings(SCEngine* engine, const char* json)
{
    if (!engine || !json)
        return;
    const QJsonObject object = QJsonDocument::fromJson(QByteArray(json)).object();
    applySettingsJson(engine->settings, object);
    // Desktop does this after toggling complex numbers or the angle unit:
    // it defines/undefines i and j and resyncs angle formatting.
    engine->evaluator->initializeBuiltInVariables();
    sc_engine_save(engine);
}

void sc_engine_save(SCEngine* engine)
{
    if (!engine || engine->dataDir.isEmpty())
        return;
    const QDir dir(engine->dataDir);
    QJsonObject sessionJson;
    engine->session->serialize(sessionJson);
    writeJsonFile(dir.filePath(kSessionFile), sessionJson);
    writeJsonFile(dir.filePath(kSettingsFile), settingsToJson(engine->settings));
}

void sc_string_free(char* string)
{
    std::free(string);
}

} // extern "C"
