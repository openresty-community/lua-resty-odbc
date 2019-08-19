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

需要注意的是，本模块提供的部分 API 的参数与 ODBC API 文档里的参数不同。比如 SQLAllocHandle 方法：

```lua
  ODBC 标准定义： 
    SQLRETURN SQLAllocHandle(SQLSMALLINT HandleType, SQLHANDLE InputHandle, SQLHANDLE *OutputHandle);

  本模块 API：
    function _M.SQLAllocHandle(handleType, inputHandle)
    end
```

SQLAllocHandle
--------------

`syntax retcode, henv = odbc.SQLAllocHandle(HandleType, InputHandle);`
参数 
----
`HandleType`
  主要由 SQLAllocHandle 分配的句柄的类型。 必须是下列值之一:
SQL_HANDLE_DBC
SQL_HANDLE_DESC
SQL_HANDLE_ENV
SQL_HANDLE_STMT

`InputHandle`
在其上下文中要分配新句柄的输入句柄。 如果HandleType为 SQL_HANDLE_ENV, 则为 SQL_NULL_HANDLE。 如果HandleType为 SQL_HANDLE_DBC, 则该句柄必须为环境句柄, 如果为 SQL_HANDLE_STMT 或 SQL_HANDLE_DESC, 则必须是连接句柄。`

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
