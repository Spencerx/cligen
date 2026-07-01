/*
 * Fuzz target: CLIgen spec (.cli) parser.
 *
 * Feeds fuzzer bytes as a CLIgen syntax specification to clispec_parse_str().
 * Exercises the Bison/Flex grammar and parse-tree construction.
 *
 * The handle is created and destroyed per input so that AddressSanitizer/
 * LeakSanitizer can attribute any parse-tree leak to the offending input.
 *
 * Build: see build.sh
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <cligen/cligen.h>

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char          *s;
    cligen_handle  h;
    cvec          *globals;

    if ((s = malloc(size + 1)) == NULL)
        return 0;
    memcpy(s, data, size);
    s[size] = '\0';                 /* NUL-terminate: parser expects a C string */

    if ((h = cligen_init()) != NULL) {
        if ((globals = cvec_new(0)) != NULL) {
            /* Return value intentionally ignored: we fuzz for crashes, not
             * for parse success/failure. */
            (void)clispec_parse_str(h, s, "fuzz", NULL, NULL, globals);
            cvec_free(globals);
        }
        cligen_exit(h);             /* frees any parse trees built into h */
    }
    free(s);
    return 0;
}
