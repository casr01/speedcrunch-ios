// sc-cli — tiny command-line driver for the bridge, used to test the engine
// without any UI.  Usage:  sc-cli "expr1" "expr2" ...   (or read lines from stdin)
#include "speedcrunch_bridge.h"
#include <cstdio>
#include <iostream>
#include <string>

static void run(SCEngine* engine, const std::string& expr)
{
    if (expr.rfind(":set ", 0) == 0) {
        sc_engine_set_settings(engine, expr.c_str() + 5);
        char* s = sc_engine_get_settings(engine);
        std::printf("settings %s\n", s);
        sc_string_free(s);
        return;
    }
    char* preview = sc_engine_preview(engine, expr.c_str());
    char* result = sc_engine_evaluate(engine, expr.c_str());
    std::printf("> %s\n  preview %s\n  result  %s\n", expr.c_str(), preview, result);
    sc_string_free(preview);
    sc_string_free(result);
}

int main(int argc, char** argv)
{
    const char* dataDir = std::getenv("SC_DATA_DIR");
    SCEngine* engine = sc_engine_create(dataDir);
    if (argc > 1) {
        for (int i = 1; i < argc; ++i)
            run(engine, argv[i]);
    } else {
        std::string line;
        while (std::getline(std::cin, line))
            run(engine, line);
    }
    sc_engine_destroy(engine);
    return 0;
}
