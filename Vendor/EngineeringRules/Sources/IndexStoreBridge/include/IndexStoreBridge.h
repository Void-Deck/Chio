#ifndef INDEX_STORE_BRIDGE_H
#define INDEX_STORE_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    const char *data;
    size_t length;
} ISBString;

typedef struct {
    ISBString usr;
    ISBString name;
    uint32_t kind;
} ISBSymbol;

typedef struct {
    uint64_t roles;
    ISBSymbol symbol;
} ISBRelation;

typedef struct {
    ISBString path;
    uint32_t line;
    uint32_t column;
    uint64_t roles;
    ISBSymbol symbol;
    const ISBRelation *relations;
    size_t relation_count;
} ISBOccurrence;

/* All strings, occurrences and relation arrays are borrowed for the callback only.
 * Returning false stops enumeration and makes the read fail. Callbacks run
 * synchronously on the calling thread. An empty main-file path denotes a module
 * unit and does not establish source coverage. */
typedef bool (*ISBOccurrenceCallback)(void *context, const ISBOccurrence *occurrence);
typedef bool (*ISBSourceCallback)(void *context, ISBString main_file);

/* Zero means success. On failure, error receives an owned message when allocation
 * succeeds. Free that message with isb_dispose_error, including after failures.
 * The library, store, unit and record readers are disposed before returning. */
int isb_read(const char *library_path, const char *store_path, void *context,
             ISBSourceCallback source_callback, ISBOccurrenceCallback occurrence_callback,
             char **error);
void isb_dispose_error(char *error);

#endif
