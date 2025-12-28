#include "postgres.h"
#include "fmgr.h"

#if PG_VERSION_NUM>=160000

#include "varatt.h"

#endif

PG_MODULE_MAGIC;

#if defined(_WIN32) && PG_VERSION_NUM<160000 // Fix bug

#define PG_FUNCTION_INFO_V1(funcname)                                            \
extern PGDLLEXPORT Datum funcname(PG_FUNCTION_ARGS);                             \
extern PGDLLEXPORT const Pg_finfo_record * CppConcat(pg_finfo_,funcname)(void);  \
const Pg_finfo_record *                                                          \
CppConcat(pg_finfo_,funcname) (void)                                             \
{                                                                                \
	static const Pg_finfo_record my_finfo = { 1 };                               \
	return &my_finfo;                                                            \
}                                                                                \
extern int no_such_variable

#endif

#define GETARG_CHARS(chars, n)								 	      \
	do {												     		  \
		bytea *param = PG_GETARG_BYTEA_P(n);                          \
		int param_size = VARSIZE_ANY_EXHDR(param);				      \
		int chars_size = sizeof(chars);							      \
		int len = param_size<chars_size ? param_size : chars_size-1;  \
		memcpy(chars, VARDATA(param), len); chars[len] = 0;           \
	} while(0);

PG_FUNCTION_INFO_V1(execute_http_request);
Datum
execute_http_request(PG_FUNCTION_ARGS)
{
	char address[32];       GETARG_CHARS   (address,      0);
	int  port             = PG_GETARG_INT32(              1);
	char auth[256];         GETARG_CHARS   (auth,         2);
	char uri[1024];         GETARG_CHARS   (uri,          3);
	char content_type[64];  GETARG_CHARS   (content_type, 4);
	int  memory_buffer_mb = PG_GETARG_INT32(              5);
	//
	size_t data_size = memory_buffer_mb*1024*1024;
	size_t data_len;
	bytea *data_bytea = palloc(VARHDRSZ+2+data_size+32);
	if (data_bytea==NULL) PG_RETURN_NULL(); // non-executable code, should be an exception in palloc function
	char *data = VARDATA(data_bytea);
	*data++='0';
	*data++=',';
	if (tcp_http_request(address, port, auth, uri, content_type, data, data_size, &data_len)) {
		data[-2] = '1';
		error_last_get(data, data_size);
		data_len = strlen(data);
	}
	SET_VARSIZE(data_bytea, VARHDRSZ+2+data_len);
	PG_RETURN_BYTEA_P(data_bytea);
}

PG_FUNCTION_INFO_V1(resolve_address_pg1c);
Datum
resolve_address_pg1c(PG_FUNCTION_ARGS)
{
	size_t address_size = 64;
	bytea *address_bytea = palloc(VARHDRSZ+address_size+32);
	if (address_bytea==NULL) PG_RETURN_NULL();
	char *address = VARDATA(address_bytea);
	if (tcp_address_hostname(address, address_size, "pg1c.org")) PG_RETURN_NULL();
    SET_VARSIZE(address_bytea, VARHDRSZ+strlen(address));
	PG_RETURN_BYTEA_P(address_bytea);
}
