/*
 * speedcrunch_bridge.h — plain C interface to the SpeedCrunch engine.
 *
 * Swift (or any C caller) talks to the engine only through these functions.
 * Data crosses the boundary as UTF-8 JSON strings so the C surface stays small.
 *
 * Rules:
 *  - Call every function from the same thread (the iOS main thread).
 *  - Every `char*` returned must be released with sc_string_free().
 *
 * Licensed under the GNU General Public License, version 2 or later,
 * like SpeedCrunch itself.
 */
#ifndef SPEEDCRUNCH_BRIDGE_H
#define SPEEDCRUNCH_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SCEngine SCEngine;

/* Creates the engine. `data_dir` is a writable directory where the session
 * (history, variables, user functions) and settings are stored as JSON.
 * Pass NULL to keep everything in memory only. */
SCEngine* sc_engine_create(const char* data_dir);
void sc_engine_destroy(SCEngine* engine);

/* Evaluates an expression and adds it to the history (like pressing Enter).
 * Returns JSON:
 *   {"ok":true, "kind":"value"|"assign"|"function"|"unit"|"comment",
 *    "expression":"<formatted>", "lines":["= 42", ...]}
 *   {"ok":false, "error":"<message>"} */
char* sc_engine_evaluate(SCEngine* engine, const char* expression);

/* Live preview while typing: evaluates without assigning variables,
 * without touching `ans` and without adding history.
 * Returns {"ok":true,"lines":[...]} or {"ok":false,"error":"..."};
 * an empty or incomplete expression returns {"ok":false,"error":""}. */
char* sc_engine_preview(SCEngine* engine, const char* expression);

/* History as JSON: [{"expression":"...", "source":"...", "lines":[...]}, ...] */
char* sc_engine_history(SCEngine* engine);
void sc_engine_clear_history(SCEngine* engine);
void sc_engine_remove_history_entry(SCEngine* engine, int index);

/* User variables (including ans): [{"name":"x","value":"5"}, ...] */
char* sc_engine_variables(SCEngine* engine);
void sc_engine_remove_variable(SCEngine* engine, const char* name);

/* User functions: [{"name":"f","arguments":["x"],"body":"x^2"}, ...] */
char* sc_engine_user_functions(SCEngine* engine);
void sc_engine_remove_user_function(SCEngine* engine, const char* name);

/* Built-in functions: [{"identifier":"sin","name":"Sine","usage":"x"}, ...] */
char* sc_engine_builtin_functions(SCEngine* engine);

/* Built-in constants: [{"name":"...","value":"...","unit":"...","domain":"...","subdomain":"..."}] */
char* sc_engine_constants(SCEngine* engine);

/* Settings as JSON:
 *   {"angleUnit":"r|d|g|t|v",
 *    "resultFormat":"g|f|n|e|r|b|o|h|s",
 *    "precision":-1..50   (-1 = automatic),
 *    "complexNumbers":bool,
 *    "decimalSeparator":"." | ",",
 *    "digitGrouping":bool   (groups of three: 1,234.5 or 1.234,5)}
 * sc_engine_set_settings accepts any subset of those keys. */
char* sc_engine_get_settings(SCEngine* engine);
void sc_engine_set_settings(SCEngine* engine, const char* json);

/* Writes session and settings to `data_dir`. Called automatically after
 * every change; exposed so the app can force a save when backgrounded. */
void sc_engine_save(SCEngine* engine);

void sc_string_free(char* string);

#ifdef __cplusplus
}
#endif

#endif /* SPEEDCRUNCH_BRIDGE_H */
