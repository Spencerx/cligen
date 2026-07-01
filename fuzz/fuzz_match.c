/*
 * Fuzz target: CLIgen command-line tokenizer + matcher.
 *
 * A fixed parse tree is built once in LLVMFuzzerInitialize(). Each fuzzer
 * input is treated as a command line: tokenized with cligen_str2cvv() and
 * matched against the tree with match_pattern_exact().
 *
 * This exercises next_token() (quote/escape/pipe handling) and the matching
 * engine, including variable type parsing and validation.
 *
 * Build: see build.sh
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <cligen/cligen.h>
#include <cligen/cligen_match.h>

static cligen_handle h;

/* A spec deliberately rich in variable types, choices, pipes, sets and
 * optionals so that many matcher code paths are reachable. */
static const char *spec =
    "prompt=\"fuzz> \";\n"
    "comment=\"#\";\n"
    "set <name:string>;\n"
    "set ip address <addr:ipv4addr> <mask:ipv4addr> [description <d:rest>];\n"
    "show (history|<count:uint32>) [detail];\n"
    "show interface <ifname:string regexp:\"e[0-9]+\">;\n"
    "show route <pfx:ipv4prefix>;\n"
    "config @{ a; b <x:int32 range[1:100]>; c <y:string choice:on|off>; }\n"
    "ping <host:ipv6addr>;\n"
    "mac <m:macaddr>;\n";

int
LLVMFuzzerInitialize(int *argc, char ***argv)
{
    cvec *globals;

    (void)argc;
    (void)argv;
    if ((h = cligen_init()) == NULL)
        abort();
    if ((globals = cvec_new(0)) == NULL)
        abort();
    if (clispec_parse_str(h, spec, "fuzz", NULL, NULL, globals) < 0)
        abort();
    cvec_free(globals);
    return 0;
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char          *s;
    cvec          *cvt = NULL;
    cvec          *cvr = NULL;
    cvec          *cvv = NULL;
    cg_obj        *match_obj = NULL;
    char          *reason = NULL;
    cligen_result  result;
    pt_head       *ph;
    parse_tree    *pt;

    if ((s = malloc(size + 1)) == NULL)
        return 0;
    memcpy(s, data, size);
    s[size] = '\0';

    if (cligen_str2cvv(s, &cvt, &cvr) == 0) {
        if ((cvv = cvec_new(0)) != NULL &&
            (ph = cligen_ph_i(h, 0)) != NULL &&
            (pt = cligen_ph_parsetree_get(ph)) != NULL) {
            /* match_obj is a COPY the caller owns and must free with co_free.
             * reason is malloc:d and must be freed. */
            (void)match_pattern_exact(h, cvt, cvr, pt, cvv,
                                      &match_obj, &result, &reason);
        }
        if (match_obj)
            co_free(match_obj, 0);
        if (reason)
            free(reason);
        if (cvv)
            cvec_free(cvv);
    }
    if (cvt)
        cvec_free(cvt);
    if (cvr)
        cvec_free(cvr);
    free(s);
    return 0;
}
