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

This Lua library  is a Transaction Queue for the ngx_lua nginx module:

https://github.com/openresty/lua-nginx-module/#readme

基于定时器的异步请求队列实现，worker 内共享，允许设置多个不同优先级别的异步队列及其队列长度，主要用于 HTTP 请求异步处理场景。Nginx接收到HTTP请求后可以先应答，后面再将请求异步提交到 Transaction Queue。

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
            
                local retcode, connOut, len = odbc.SQLDriverConnect(hdbc, nil, "DSN=odbctest", odbc.SQL_NTS, odbc.SQL_DRIVER_NOPROMPT);
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

本模块提供的所有 API 都跟 ODBC 标准定义的 API 名字相同。可以在下面的文档中获取完整的 API 列表：

https://docs.microsoft.com/zh-cn/sql/odbc/reference/syntax/odbc-api-reference?view=sql-server-2017

需要注意的是，本模块提供的部分 API 的parameter与 ODBC API 文档里的parameter不同。比如 SQLAllocHandle 方法：

```lua
  ODBC 标准定义： 
    SQLRETURN SQLAllocHandle(SQLSMALLINT HandleType, SQLHANDLE InputHandle, SQLHANDLE *OutputHandle);

  本模块 API：
    function _M.SQLAllocHandle(handleType, inputHandle)
    end
```

[Back to TOC](#table-of-contents)

SQLAllocHandle
--------------

syntax
------

retcode, henv = odbc.SQLAllocHandle(HandleType, InputHandle);

parameter 
----

`HandleType`  主要由 SQLAllocHandle 分配的句柄的类型。 必须是下列值之一: SQL_HANDLE_DBC, SQL_HANDLE_DESC, SQL_HANDLE_ENV, SQL_HANDLE_STMT

`InputHandle` 在其上下文中要分配新句柄的输入句柄。 如果HandleType为 SQL_HANDLE_ENV, 则为 SQL_NULL_HANDLE。 如果HandleType为 SQL_HANDLE_DBC, 则该句柄必须为环境句柄, 如果为 SQL_HANDLE_STMT 或 SQL_HANDLE_DESC, 则必须是连接句柄。`

[Back to TOC](#table-of-contents)

SQLSetEnvAttr
-------------

syntax
------

retcode = odbc.SQLSetEnvAttr(EnvironmentHandle, Attribute, Value);

parameter
----

`EnvironmentHandle` 环境句柄

`Attribute` 要设置的属性, 参考 ODBC 标准

`Value` 指向要与属性关联的值

[Back to TOC](#table-of-contents)

SQLSetConnectAttr
-----------------

syntax
------

retcode = odbc.SQLSetConnectAttr(ConnectionHandle, Attribute, Value)

parameter
----

`ConnectionHandle` 连接句柄

`Attribute` 要设置的属性,  参考 ODBC 标准

`Value` 指向要与属性关联的值

[Back to TOC](#table-of-contents)

SQLSetStmtAttr
--------------

syntax
------

retcode = odbc.SQLSetStmtAttr(StatementHandle, Attribute, Value)

parameter
----

`StatementHandle` 语句句柄

`Attribute` 要设置的属性,  参考 ODBC 标准

`Value` 指向要与属性关联的值

[Back to TOC](#table-of-contents)

SQLDriverConnect
----------------

syntax
------

retcode, connOut, len = odbc.SQLDriverConnect(ConnectionHandle, WindowHandle, InConnectionString, DriverCompletion);

parameter
----

`ConnectionHandle` 连接句柄

`WindowHandle` 窗口句柄。 应用程序可以通过父窗口的句柄，如果适用，或如果是 null 指针的窗口句柄不适用或 SQLDriverConnect 将不显示任何对话框

`InConnectionString` 完整的连接字符串, 参考 ODBC 标准

`DriverCompletion` 该标志指示驱动程序管理器或驱动程序必须提示输入连接的详细信息：SQL_DRIVER_PROMPT、 SQL_DRIVER_COMPLETE、 SQL_DRIVER_COMPLETE_REQUIRED 时或 SQL_DRIVER_NOPROMPT

[Back to TOC](#table-of-contents)

SQLPrepare
----------

retcode = odbc.SQLPrepare(StatementHandle, StatementText);

syntax
------

`StatementHandle` 语句句柄

`StatementText` 要执行的 SQL

parameter
----

[Back to TOC](#table-of-contents)

SQLExecute
----------

syntax
------

retcode = odbc.SQLExecute(StatementHandle, Timeout);

parameter
----

`StatementHandle` 语句句柄

`Timeout` 超时时间

[Back to TOC](#table-of-contents)

SQLExecuteAsync
---------------

syntax
------

retcode = odbc.SQLExecuteAsync(ConnectionHandle, StatementHandle, Timeout);

parameter
--------

`ConnectionHandle` 连接句柄

`StatementHandle` 语句句柄

`Timeout` 超时时间

[Back to TOC](#table-of-contents)

SQLBindCol
----------

syntax
------

retcode, col, res = odbc.SQLBindCol(StatementHandle, ColumnNumber, TargetType);

parameter
----

`StatementHandle` 语句句柄

`ColumnNumber` 要绑定的列集的结果数。 列中从 0 开始，其中第 0 列书签列的列顺序递增编号。 如果不使用书签-也就是说，SQL_ATTR_USE_BOOKMARKS 语句属性设置为 SQL_UB_OFF-然后列号从 1 开始

`TargetType` C 数据类型的标识符

[Back to TOC](#table-of-contents)

SQLFetch
--------

syntax
------

retcode = odbc.SQLFetch(StatementHandle)

parameter
---------

`StatementHandle` 语句句柄

[Back to TOC](#table-of-contents)

SQLExecDirect
-------------

syntax
------

retcode = SQLExecDirect(StatementHandle, StatementText, Timeout)

parameter
----

`StatementHandle` 语句句柄

`StatementText` 若要执行的 SQL 语句

`Timeout` 超时时间

[Back to TOC](#table-of-contents)

SQLFreeHandle
-------------

syntax
------

retcode = odbc.SQLFreeHandle(HandleType, Handle);

parameter
----

`HandleType` 要由SQLFreeHandle释放的句柄的类型。 必须是下列值之一:SQL_HANDLE_DBC, SQL_HANDLE_DESC, SQL_HANDLE_ENV, SQL_HANDLE_STMT. 如果HandleType不是这些值之一, SQLFREEHANDLE将返回 SQL_INVALID_HANDLE
`Handle` 要释放的句柄

[Back to TOC](#table-of-contents)

SQLDisconnect
-------------

syntax
------

retcode = odbc.SQLDisconnect(ConnectionHandle);

parameter
---------

`ConnectionHandle` 连接句柄

[Back to TOC](#table-of-contents)

Limitations
===========

[Back to TOC](#table-of-contents)

TODO
====

[Back to TOC](#table-of-contents)

Author
======

[Back to TOC](#table-of-contents)

Copyright and License
=====================

[Back to TOC](#table-of-contents)

See Also
========

[Back to TOC](#table-of-contents)
