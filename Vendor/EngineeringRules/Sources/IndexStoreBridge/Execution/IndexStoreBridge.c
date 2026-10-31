#include "IndexStoreBridge.h"

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* These declarations describe the stable C ABI, not the index's private on-disk
 * format. The matching compiler toolchain supplies libIndexStore at runtime. */
typedef void *Handle;
typedef bool (*HandleCallback)(void *, Handle);
typedef bool (*StringCallback)(void *, ISBString);

typedef struct {
    Handle (*store_create)(const char *, Handle *);
    void (*store_dispose)(Handle);
    bool (*units_apply)(Handle, unsigned, void *, StringCallback);
    Handle (*unit_create)(Handle, const char *, Handle *);
    void (*unit_dispose)(Handle);
    ISBString (*unit_main_file)(Handle);
    bool (*dependencies_apply)(Handle, void *, HandleCallback);
    unsigned (*dependency_kind)(Handle);
    ISBString (*dependency_name)(Handle);
    ISBString (*dependency_path)(Handle);
    Handle (*record_create)(Handle, const char *, Handle *);
    void (*record_dispose)(Handle);
    bool (*symbols_apply)(Handle, bool, void *, HandleCallback);
    bool (*occurrences_apply)(Handle, void *, HandleCallback);
    Handle (*occurrence_symbol)(Handle);
    uint64_t (*occurrence_roles)(Handle);
    void (*occurrence_location)(Handle, unsigned *, unsigned *);
    bool (*relations_apply)(Handle, void *, HandleCallback);
    Handle (*relation_symbol)(Handle);
    uint64_t (*relation_roles)(Handle);
    ISBString (*symbol_usr)(Handle);
    ISBString (*symbol_name)(Handle);
    unsigned (*symbol_kind)(Handle);
    const char *(*error_description)(Handle);
    void (*error_dispose)(Handle);
} API;

typedef struct {
    API api;
    Handle store;
    void *context;
    ISBSourceCallback source_callback;
    ISBOccurrenceCallback occurrence_callback;
    char **error;
    bool failed;
    size_t units;
    size_t records;
    size_t occurrences;
    size_t symbols;
    size_t relations;
    size_t string_bytes;
} Reader;

typedef struct {
    Reader *reader;
    ISBString path;
} Record;

typedef struct {
    Reader *reader;
    bool has_symbols;
} RecordSymbols;

typedef struct {
    Reader *reader;
    ISBRelation *values;
    size_t count;
    size_t capacity;
} Relations;

enum {
    maximum_string_bytes = 1024 * 1024,
    maximum_total_string_bytes = 256 * 1024 * 1024,
    maximum_units = 16384,
    maximum_records = 65536,
    maximum_occurrences = 2000000,
    maximum_symbols = 2000000,
    maximum_relations = 8000000,
    maximum_occurrence_relations = 4096
};

static bool fail(Reader *reader, const char *message) {
    if (!reader->failed) {
        reader->failed = true;
        if (reader->error != NULL) {
            size_t length = strnlen(message, maximum_string_bytes);
            char *copy = malloc(length + 1);
            if (copy != NULL) {
                memcpy(copy, message, length);
                copy[length] = '\0';
                *reader->error = copy;
            }
        }
    }
    return false;
}

static bool consume_error(Reader *reader, Handle error, const char *fallback) {
    const char *message = error == NULL ? fallback : reader->api.error_description(error);
    fail(reader, message == NULL ? fallback : message);
    if (error != NULL) reader->api.error_dispose(error);
    return false;
}

static bool valid_string(Reader *reader, ISBString value) {
    if (value.length > maximum_string_bytes || (value.length != 0 && value.data == NULL)) {
        return fail(reader, "Invalid or oversized string in compiler index");
    }
    if (value.length > maximum_total_string_bytes - reader->string_bytes) {
        return fail(reader, "Compiler index exceeds the string data limit");
    }
    reader->string_bytes += value.length;
    return true;
}

static char *terminated_string(Reader *reader, ISBString value) {
    if (!valid_string(reader, value)) return NULL;
    if (value.length == 0 || memchr(value.data, '\0', value.length) != NULL) {
        fail(reader, "Empty or malformed reader name in compiler index");
        return NULL;
    }
    char *copy = malloc(value.length + 1);
    if (copy == NULL) {
        fail(reader, "Cannot allocate compiler index reader name");
        return NULL;
    }
    memcpy(copy, value.data, value.length);
    copy[value.length] = '\0';
    return copy;
}

static bool read_symbol(Reader *reader, Handle handle, ISBSymbol *symbol) {
    if (handle == NULL) return fail(reader, "Missing symbol in compiler index");
    symbol->usr = reader->api.symbol_usr(handle);
    symbol->name = reader->api.symbol_name(handle);
    symbol->kind = reader->api.symbol_kind(handle);
    return valid_string(reader, symbol->usr) && valid_string(reader, symbol->name);
}

static bool read_relation(void *context, Handle handle) {
    Relations *relations = context;
    Reader *reader = relations->reader;
    if (++reader->relations > maximum_relations || relations->count >= maximum_occurrence_relations) {
        return fail(reader, "Compiler index exceeds the relation limit");
    }
    if (relations->count == relations->capacity) {
        size_t capacity = relations->capacity == 0 ? 8 : relations->capacity * 2;
        ISBRelation *values = realloc(relations->values, capacity * sizeof(ISBRelation));
        if (values == NULL) return fail(reader, "Cannot allocate compiler index relations");
        relations->values = values;
        relations->capacity = capacity;
    }
    ISBRelation *value = &relations->values[relations->count];
    value->roles = reader->api.relation_roles(handle);
    if (!read_symbol(reader, reader->api.relation_symbol(handle), &value->symbol)) return false;
    ++relations->count;
    return true;
}

static bool read_occurrence(void *context, Handle handle) {
    Record *record = context;
    Reader *reader = record->reader;
    if (++reader->occurrences > maximum_occurrences) {
        return fail(reader, "Compiler index exceeds the occurrence limit");
    }
    ISBOccurrence occurrence = {0};
    occurrence.path = record->path;
    occurrence.roles = reader->api.occurrence_roles(handle);
    reader->api.occurrence_location(handle, &occurrence.line, &occurrence.column);
    if (!read_symbol(reader, reader->api.occurrence_symbol(handle), &occurrence.symbol)) return false;
    Relations relations = {.reader = reader};
    bool enumerated = reader->api.relations_apply(handle, &relations, read_relation);
    if (!enumerated && !reader->failed) fail(reader, "Cannot enumerate compiler index relations");
    if (!reader->failed) {
        occurrence.relations = relations.values;
        occurrence.relation_count = relations.count;
        if (!reader->occurrence_callback(reader->context, &occurrence)) {
            fail(reader, "Compiler index occurrence callback rejected data");
        }
    }
    free(relations.values);
    return !reader->failed;
}

static bool read_record_symbol(void *context, Handle handle) {
    RecordSymbols *symbols = context;
    Reader *reader = symbols->reader;
    if (++reader->symbols > maximum_symbols) {
        return fail(reader, "Compiler index exceeds the symbol limit");
    }
    ISBSymbol symbol;
    if (!read_symbol(reader, handle, &symbol)) return false;
    symbols->has_symbols = true;
    return true;
}

static bool read_dependency(void *context, Handle dependency) {
    Reader *reader = context;
    /* Record dependencies carry the exact record identifier and source path.
     * Unit/file dependencies do not establish a source occurrence record. */
    if (reader->api.dependency_kind(dependency) != 2) return true;
    if (++reader->records > maximum_records) return fail(reader, "Compiler index exceeds the record limit");
    ISBString path = reader->api.dependency_path(dependency);
    if (!valid_string(reader, path) || path.length == 0) {
        return fail(reader, "Missing record source path in compiler index");
    }
    char *name = terminated_string(reader, reader->api.dependency_name(dependency));
    if (name == NULL) return false;
    Handle error = NULL;
    Handle record = reader->api.record_create(reader->store, name, &error);
    free(name);
    if (record == NULL || error != NULL) {
        if (record != NULL) reader->api.record_dispose(record);
        return consume_error(reader, error, "Cannot open compiler index record");
    }
    RecordSymbols symbols = {.reader = reader};
    bool enumerated = reader->api.symbols_apply(record, true, &symbols, read_record_symbol);
    if (!enumerated && !reader->failed) fail(reader, "Cannot enumerate compiler index symbols");
    /* The native writer omits declaration/occurrence blocks for zero-symbol
     * records. Its occurrence API cannot traverse that absent block. Classify
     * emptiness through successful symbol enumeration instead of accepting a
     * failed occurrence traversal. The enclosing source unit still proves input
     * coverage, including a source containing only comments. */
    if (!reader->failed && symbols.has_symbols) {
        Record record_context = {.reader = reader, .path = path};
        enumerated = reader->api.occurrences_apply(record, &record_context, read_occurrence);
        if (!enumerated && !reader->failed) fail(reader, "Cannot enumerate compiler index occurrences");
    }
    reader->api.record_dispose(record);
    return !reader->failed;
}

static bool read_unit(void *context, ISBString unit_name) {
    Reader *reader = context;
    if (++reader->units > maximum_units) return fail(reader, "Compiler index exceeds the unit limit");
    char *name = terminated_string(reader, unit_name);
    if (name == NULL) return false;
    Handle error = NULL;
    Handle unit = reader->api.unit_create(reader->store, name, &error);
    free(name);
    if (unit == NULL || error != NULL) {
        if (unit != NULL) reader->api.unit_dispose(unit);
        return consume_error(reader, error, "Cannot open compiler index unit");
    }
    ISBString main_file = reader->api.unit_main_file(unit);
    bool accepted = valid_string(reader, main_file);
    if (accepted) accepted = reader->source_callback(reader->context, main_file);
    if (!accepted && !reader->failed) fail(reader, "Compiler index source callback rejected data");
    if (!reader->failed) {
        bool enumerated = reader->api.dependencies_apply(unit, reader, read_dependency);
        if (!enumerated && !reader->failed) fail(reader, "Cannot enumerate compiler index dependencies");
    }
    reader->api.unit_dispose(unit);
    return !reader->failed;
}

int isb_read(const char *library_path, const char *store_path, void *context,
             ISBSourceCallback source_callback, ISBOccurrenceCallback occurrence_callback,
             char **error) {
    if (error != NULL) *error = NULL;
    Reader reader = {.context = context, .source_callback = source_callback,
                     .occurrence_callback = occurrence_callback, .error = error};
    if (library_path == NULL || store_path == NULL || source_callback == NULL || occurrence_callback == NULL) {
        fail(&reader, "Invalid compiler index reader arguments");
        return 1;
    }
    void *library = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
    if (library == NULL) {
        const char *description = dlerror();
        fail(&reader, description == NULL ? "Cannot load libIndexStore" : description);
        return 1;
    }
#define LOAD(field, name) do { \
    void *address = dlsym(library, name); \
    if (address == NULL || sizeof(reader.api.field) != sizeof(address)) { \
        fail(&reader, "Missing libIndexStore API: " name); \
        goto cleanup; \
    } \
    memcpy(&reader.api.field, &address, sizeof(address)); \
} while (0)
    LOAD(store_create, "indexstore_store_create");
    LOAD(store_dispose, "indexstore_store_dispose");
    LOAD(units_apply, "indexstore_store_units_apply_f");
    LOAD(unit_create, "indexstore_unit_reader_create");
    LOAD(unit_dispose, "indexstore_unit_reader_dispose");
    LOAD(unit_main_file, "indexstore_unit_reader_get_main_file");
    LOAD(dependencies_apply, "indexstore_unit_reader_dependencies_apply_f");
    LOAD(dependency_kind, "indexstore_unit_dependency_get_kind");
    LOAD(dependency_name, "indexstore_unit_dependency_get_name");
    LOAD(dependency_path, "indexstore_unit_dependency_get_filepath");
    LOAD(record_create, "indexstore_record_reader_create");
    LOAD(record_dispose, "indexstore_record_reader_dispose");
    LOAD(symbols_apply, "indexstore_record_reader_symbols_apply_f");
    LOAD(occurrences_apply, "indexstore_record_reader_occurrences_apply_f");
    LOAD(occurrence_symbol, "indexstore_occurrence_get_symbol");
    LOAD(occurrence_roles, "indexstore_occurrence_get_roles");
    LOAD(occurrence_location, "indexstore_occurrence_get_line_col");
    LOAD(relations_apply, "indexstore_occurrence_relations_apply_f");
    LOAD(relation_symbol, "indexstore_symbol_relation_get_symbol");
    LOAD(relation_roles, "indexstore_symbol_relation_get_roles");
    LOAD(symbol_usr, "indexstore_symbol_get_usr");
    LOAD(symbol_name, "indexstore_symbol_get_name");
    LOAD(symbol_kind, "indexstore_symbol_get_kind");
    LOAD(error_description, "indexstore_error_get_description");
    LOAD(error_dispose, "indexstore_error_dispose");
#undef LOAD
    Handle store_error = NULL;
    reader.store = reader.api.store_create(store_path, &store_error);
    if (reader.store == NULL || store_error != NULL) {
        consume_error(&reader, store_error, "Cannot open compiler index store");
        goto cleanup;
    }
    if (!reader.api.units_apply(reader.store, 1, &reader, read_unit) && !reader.failed) {
        fail(&reader, "Cannot enumerate compiler index units");
    }
    if (reader.units == 0 && !reader.failed) fail(&reader, "Compiler index contains no units");
cleanup:
    if (reader.store != NULL) reader.api.store_dispose(reader.store);
    dlclose(library);
    return reader.failed ? 1 : 0;
}

void isb_dispose_error(char *error) {
    free(error);
}
