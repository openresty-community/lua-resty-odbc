Name
====

lua-resty-transaction-queue - Lua Transaction Queue for the ngx_lua

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Description](#description)
* [Synopsis](#synopsis)
* [Methods](#methods)
    * [SQLAllocHandle](#SQLAllocHandle)
    * [SQLSetEnvAttr](#SQLSetEnvAttr)
    * [SQLSetConnectAttr](#SQLSetConnectAttr)
    * [SQLSetStmtAttr](#SQLSetStmtAttr)
    * [SQLDriverConnect](#SQLDriverConnect)
    * [SQLPrepare](#SQLPrepare)
    * [SQLExecute](#SQLExecute)
    * [SQLExecuteAsync](#SQLExecuteAsync)
    * [SQLBindCol](#SQLBindCol)
    * [SQLFetch](#SQLFetch)
    * [SQLExecDirect](#SQLExecDirect)
    * [SQLFreeHandle](#SQLFreeHandle)
    * [SQLDisconnect](#SQLDisconnect)
* [Limitations](#limitations)
* [TODO](#todo)
* [Author](#author)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Status
======

Description
===========

This Lua library is a ODBC client driver for the ngx_lua nginx module:

https://github.com/openresty/lua-nginx-module/#readme

This Module is implementation of ODBC database access standard based on Lua. It wraps the unix-ODBC C library and is a fully asynchronous model. Developers can use this module in a synchronous manner, which simplifies business development complexity. In addition, the module also provides long transaction timeout detection and abort capabilities. Developers can send sql to the database by the ODBC asynchronous interface and set execute timeout. if the query execute timeout, the module can detect and automatically kill the connection

Synopsis
========

```lua
    lua_package_path "/path/to/lua-resty-odbc/lib/?.lua;;";

    server {
        location /test {
            content_by_lua '
                local odbc = require("odbc")
                local retcode, henv = odbc.SQLAllocHandle(odbc.SQL_HANDLE_ENV, odbc.SQL_NULL_HANDLE);
                if retcode then
                  return
                end
                
                retcode = odbc.SQLSetEnvAttr(henv, odbc.SQL_ATTR_ODBC_VERSION, odbc.SQL_OV_ODBC3_80, 0);
                if retcode then
                  return
                end
            
                local retcode, hdbc = odbc.SQLAllocHandle(odbc.SQL_HANDLE_DBC, henv);
                if retcode then
                  return
                end
            
                retcode = odbc.SQLSetConnectAttr(hdbc, odbc.SQL_LOGIN_TIMEOUT, 5, 0);
                if retcode then
                  return
                end
            
                local retcode, connOut = odbc.SQLDriverConnect(hdbc, nil, "DSN=odbctest", odbc.SQL_NTS, odbc.SQL_DRIVER_NOPROMPT);
                if retcode then
                  return
                end
            
                local retcode, hstmt = odbc.SQLAllocHandle(odbc.SQL_HANDLE_STMT, hdbc);
                if retcode then
                  return
                end
            
                retcode = odbc.SQLPrepare(hstmt, "select 1 from dual", odbc.SQL_NTS);
                if retcode then
                  return
                end
            
                local retcode = odbc.SQLExecuteAsync(hdbc, hstmt);
                if retcode then
                  return
                end
            
                local retcode, col, res = odbc.SQLBindCol(hstmt, 1, odbc.SQL_C_LONG);
                if retcode then
                  return
                end
            
                retcode = odbc.SQLFetch(hstmt)
                ngx.log(ngx.NOTICE, "retcode:", retcode, ", type:", type(col), ", value:", col[0])

                odbc.SQLFreeHandle(odbc.SQL_HANDLE_STMT, hstmt);
                odbc.SQLDisconnect(hdbc);
                odbc.SQLFreeHandle(odbc.SQL_HANDLE_DBC, hdbc);
                odbc.SQLFreeHandle(odbc.SQL_HANDLE_ENV, henv);
            ';
        }
    }
```

[Back to TOC](#table-of-contents)

Methods
=======

All APIs provided by this module are the same as the API names defined by the ODBC standard. A complete list of APIs can be found in the documentation below:

https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/odbc-api-reference?view=sql-server-2017

It should be noted that the argumentss of some APIs provided by this module are different from the argumentss in the ODBC API documentation. As follows:

```lua
  ODBC standard:
    SQLRETURN SQLAllocHandle(SQLSMALLINT HandleType, SQLHANDLE InputHandle, SQLHANDLE *OutputHandle);

  define in this module:
    function _M.SQLAllocHandle(handleType, inputHandle)
    end
```
The first return value of all APIs is retcode, Must be one of the following values: SQL_SUCCESS, SQL_SUCCESS_WITH_INFO, SQL_ERROR, SQL_INVALID_HANDLE, or SQL_STILL_EXECUTING

[Back to TOC](#table-of-contents)

SQLAllocHandle
--------------

Allocates an environment, connection, statement, or descriptor handle

syntax
------

retcode, handle = odbc.SQLAllocHandle(HandleType, InputHandle);

arguments 
----

`HandleType`  The type of handle to be allocated by SQLAllocHandle. Must be one of the following values: SQL_HANDLE_DBC, SQL_HANDLE_DESC, SQL_HANDLE_ENV, SQL_HANDLE_STMT

`InputHandle` The input handle in whose context the new handle is to be allocated. If HandleType is SQL_HANDLE_ENV, this is SQL_NULL_HANDLE. If HandleType is SQL_HANDLE_DBC, this must be an environment handle, and if it is SQL_HANDLE_STMT or SQL_HANDLE_DESC, it must be a connection handle.

returns
------

`handle` The newly allocated handle

[Back to TOC](#table-of-contents)

SQLSetEnvAttr
-------------

Sets attributes that govern aspects of environments

syntax
------

retcode = odbc.SQLSetEnvAttr(EnvironmentHandle, Attribute, Value);

arguments
----

`EnvironmentHandle` Environment handle

`Attribute` Attribute to set, Reference ODBC standard

`Value` The value to be associated with Attribute

[Back to TOC](#table-of-contents)

SQLSetConnectAttr
-----------------

Sets attributes that govern aspects of connections

syntax
------

retcode = odbc.SQLSetConnectAttr(ConnectionHandle, Attribute, Value)

arguments
----

`ConnectionHandle` Connection handle

`Attribute` Attribute to set, Reference ODBC standard

`Value` The value to be associated with Attribute

[Back to TOC](#table-of-contents)

SQLSetStmtAttr
--------------

Sets attributes related to a statement

syntax
------

retcode = odbc.SQLSetStmtAttr(StatementHandle, Attribute, Value)

arguments
----

`StatementHandle` Statement handle

`Attribute` Attribute to set, Reference ODBC standard

`Value` The value to be associated with Attribute

[Back to TOC](#table-of-contents)

SQLDriverConnect
----------------

Establish a connection

syntax
------

retcode, connOut = odbc.SQLDriverConnect(ConnectionHandle, WindowHandle, InConnectionString, DriverCompletion);

arguments
----

`ConnectionHandle` Connection handle

`WindowHandle` Window handle. The application can pass the handle of the parent window, if applicable, or a null pointer if either the window handle is not applicable or SQLDriverConnect will not present any dialog boxes

`InConnectionString` A full connection string, Reference ODBC standard

`DriverCompletion` Flag that indicates whether the Driver Manager or driver must prompt for more connection information: SQL_DRIVER_PROMPT, SQL_DRIVER_COMPLETE, SQL_DRIVER_COMPLETE_REQUIRED, SQL_DRIVER_NOPROMPT

returns
------

`connOut` The completed connection string. Upon successful connection to the target data source, this contains the completed connection string.

[Back to TOC](#table-of-contents)

SQLPrepare
----------

Prepares an SQL string for execution

syntax
------

retcode = odbc.SQLPrepare(StatementHandle, StatementText);

arguments
----

`StatementHandle` Statement handle

`StatementText` SQL text string

[Back to TOC](#table-of-contents)

SQLExecute
----------

Executes a prepared statement, using the current values of the parameter marker variables if any parameter markers exist in the statement.

syntax
------

retcode = odbc.SQLExecute(StatementHandle, Timeout);

arguments
----

`StatementHandle` Statement handle

`Timeout` Set execute timeout

[Back to TOC](#table-of-contents)

SQLExecuteAsync
---------------

Asynchronous executes a prepared statement, using the current values of the parameter marker variables if any parameter markers exist in the statement.

syntax
------

retcode = odbc.SQLExecuteAsync(ConnectionHandle, StatementHandle, Timeout);

arguments
--------

`ConnectionHandle` Connection handle

`StatementHandle` Statement handle

`Timeout` Set execute timeout

[Back to TOC](#table-of-contents)

SQLBindCol
----------

Binds application data buffers to columns in the result set

syntax
------

retcode, col, res = odbc.SQLBindCol(StatementHandle, ColumnNumber, TargetType);

arguments
----

`StatementHandle` Statement handle

`ColumnNumber` Number of the result set column to bind. Columns are numbered in increasing column order starting at 0, where column 0 is the bookmark column. If bookmarks are not used - that is, the SQL_ATTR_USE_BOOKMARKS statement attribute is set to SQL_UB_OFF - then column numbers start at 1

`TargetType` The identifier of the C data type

returns
------

`col` The data buffer to bind to the column. SQLFetch and SQLFetchScroll return data in this buffer

`res` The length/indicator buffer to bind to the column. SQLFetch and SQLFetchScroll return a value in this buffer

[Back to TOC](#table-of-contents)

SQLFetch
--------

Fetches the next rowset of data from the result set and returns data for all bound columns

syntax
------

retcode = odbc.SQLFetch(StatementHandle)

arguments
---------

`StatementHandle` Statement handle

[Back to TOC](#table-of-contents)

SQLExecDirect
-------------

Executes a preparable statement, using the current values of the parameter marker variables if any parameters exist in the statement. SQLExecDirect is the fastest way to submit an SQL statement for one-time execution

syntax
------

retcode = SQLExecDirect(StatementHandle, StatementText, Timeout)

arguments
----

`StatementHandle` Statement handle

`StatementText` SQL statement to be executed

`Timeout` Set execute timeout

[Back to TOC](#table-of-contents)

SQLFreeHandle
-------------

Frees resources associated with a specific environment, connection, statement, or descriptor handle

syntax
------

retcode = odbc.SQLFreeHandle(HandleType, Handle);

arguments
----

`HandleType` The type of handle to be freed by SQLFreeHandle. Must be one of the following values: SQL_HANDLE_DBC, SQL_HANDLE_DESC, SQL_HANDLE_ENV, SQL_HANDLE_STMT. If HandleType is not one of these values, SQLFreeHandle returns SQL_INVALID_HANDLE.

`Handle` The handle to be freed

[Back to TOC](#table-of-contents)

SQLDisconnect
-------------

Closes the connection associated with a specific connection handle

syntax
------

retcode = odbc.SQLDisconnect(ConnectionHandle);

arguments
---------

`ConnectionHandle` Connection handle

[Back to TOC](#table-of-contents)

Limitations
===========

[Back to TOC](#table-of-contents)

TODO
====

[Back to TOC](#table-of-contents)

Author
======

Guangshu Wang (Wesley) <guangshu.wgs@antfin.com>, Ant Financial Inc.

[Back to TOC](#table-of-contents)

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2019, by Guangshu Wang (Wesley) <guangshu.wgs@antfin.com>, Ant Financial Inc.

All rights reserved.

[Back to TOC](#table-of-contents)

See Also
========

[Back to TOC](#table-of-contents)
