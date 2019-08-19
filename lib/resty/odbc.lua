local ffi = require "ffi"
local ngx_odbc = require "ngx.odbc"
local _M = { _VERSION = '0.0.1' }
local mt = { __index = _M }
local conn_table = {}

local self = {
  SQL_HANDLE_ENV = 1,
  SQL_HANDLE_DBC = 2,
  SQL_HANDLE_STMT = 3,
  SQL_NULL_HANDLE = nil,

  SQL_ATTR_ODBC_VERSION = 200,
  SQL_OV_ODBC3_80 = 380,

  SQL_QUERY_TIMEOUT = 0,
  SQL_LOGIN_TIMEOUT = 103,

  SQL_NTS = -3,
  SQL_DRIVER_NOPROMPT = 0,

  SQL_INTEGER = 4,
  SQL_C_LONG = 4,
}

local load_shared_lib
do
  local string_gmatch = string.gmatch
  local string_match = string.match
  local io_open = io.open
  local io_close = io.close

  local cpath = package.cpath

  function load_shared_lib(so_name)
    local tried_paths = {} 
    local i = 1

    for k, _ in string_gmatch(cpath, "[^;]+") do
      local fpath = string_match(k, "(.*/)")
      fpath = fpath .. so_name
      -- Don't get me wrong, the only way to know if a file exist is
      -- trying to open it.
      local f = io_open(fpath)
      if f ~= nil then
        io_close(f)
        return ffi.load(fpath)
      end

      tried_paths[i] = fpath
      i = i + 1
    end

    return nil, tried_paths
  end  -- function
end  -- do

local odbc, tried_paths = load_shared_lib("libodbc.so")
if not odbc then
  error("could not load libodbc.so from the following paths:\n" ..
        table.concat(tried_paths, "\n"), 2)
end

ffi.cdef[[
  typedef void *  SQLHANDLE; 
  typedef SQLHANDLE SQLHENV;
  typedef SQLHANDLE SQLHDBC;
  typedef SQLHANDLE SQLHSTMT;
  typedef SQLHANDLE SQLHWND;

  typedef signed short int   SQLSMALLINT;
  typedef SQLSMALLINT        SQLRETURN;
  typedef int                SQLINTEGER;
  typedef void *             SQLPOINTER;
  typedef unsigned char      SQLCHAR;
  typedef unsigned long      SQLSETPOSIROW;
  typedef SQLSETPOSIROW      SQLUSMALLINT;
  typedef SQLINTEGER         SQLLEN;

  SQLRETURN SQLAllocHandle(SQLSMALLINT HandleType, SQLHANDLE InputHandle, SQLHANDLE *OutputHandle);
  SQLRETURN SQLSetEnvAttr(SQLHENV EnvironmentHandle,
                          SQLINTEGER Attribute, SQLPOINTER Value,
                          SQLINTEGER StringLength);
  SQLRETURN SQLAllocHandle(SQLSMALLINT HandleType,
                           SQLHANDLE InputHandle, SQLHANDLE *OutputHandle);
  SQLRETURN SQLSetConnectAttr(SQLHDBC ConnectionHandle,
                              SQLINTEGER Attribute, SQLPOINTER Value,
                              SQLINTEGER StringLength);
  SQLRETURN SQLDriverConnect(SQLHDBC      hdbc,
                             SQLHWND      hwnd,
			     SQLCHAR      *szConnStrIn,
			     SQLSMALLINT  cbConnStrIn,
			     SQLCHAR      *szConnStrOut,
			     SQLSMALLINT  cbConnStrOutMax,
			     SQLSMALLINT  *pcbConnStrOut,
			     SQLUSMALLINT fDriverCompletion);
   SQLRETURN  SQLError(SQLHENV EnvironmentHandle,
                       SQLHDBC ConnectionHandle, SQLHSTMT StatementHandle,
                       SQLCHAR *Sqlstate, SQLINTEGER *NativeError,
                       SQLCHAR *MessageText, SQLSMALLINT BufferLength,
                       SQLSMALLINT *TextLength);
   SQLRETURN  SQLPrepare(SQLHSTMT StatementHandle,
                         SQLCHAR *StatementText, SQLINTEGER TextLength);
   SQLRETURN  SQLExecute(SQLHSTMT StatementHandle);
   SQLRETURN  SQLExecuteAsync(SQLHSTMT statement_handle, int* status);
   SQLRETURN  SQLGetAsyncConnFd(SQLHDBC ConnectionHandle, int* fd);
   SQLRETURN  SQLExecDirect(SQLHSTMT StatementHandle,
                            SQLCHAR *StatementText, SQLINTEGER TextLength);
   SQLRETURN  SQLBindCol(SQLHSTMT StatementHandle,
                         SQLUSMALLINT ColumnNumber, SQLSMALLINT TargetType,
			 SQLPOINTER TargetValue, SQLLEN BufferLength,
			 SQLLEN *StrLen_or_Ind);
   SQLRETURN  SQLFetch(SQLHSTMT StatementHandle);
   SQLRETURN  SQLFreeHandle(SQLSMALLINT HandleType, SQLHANDLE Handle);
   SQLRETURN  SQLDisconnect(SQLHDBC ConnectionHandle);
   SQLRETURN  SQLSetStmtAttr(SQLHSTMT StatementHandle,
                             SQLINTEGER Attribute, SQLPOINTER Value,
                             SQLINTEGER StringLength);
]]

local handle_type = ffi.typeof("SQLHANDLE[1]")
local smallint_type = ffi.typeof("SQLSMALLINT[1]")
local integer_type = ffi.typeof("SQLINTEGER[1]")
local MAX_NAME_LEN = 1024
local szConnStrOut_ptr = ffi.new("char[?]", MAX_NAME_LEN + 1)

function _M.checkError(henv, hdbc, hstmt)
  local len = ffi.new(smallint_type)

  local SQL_SQLSTATE_SIZE	= 5
  local sqlstate = ffi.new("char[?]", SQL_SQLSTATE_SIZE)
  local error_c = ffi.new(integer_type)

  local SQL_MAX_MESSAGE_LENGTH = 512
  local message = ffi.new("char[?]", SQL_MAX_MESSAGE_LENGTH)
  odbc.SQLError(henv, hdbc, hstmt, sqlstate, error_c, message, SQL_MAX_MESSAGE_LENGTH, len)
  ngx.log(ngx.ERR, "error:", error_c[0], ", message:", ffi.string(message), ", sqlstate:", ffi.string(sqlstate), ", len:", len[0])
end

function _M.SQLAllocHandle(handleType, inputHandle)
  local handle = ffi.new(handle_type)
  local retcode = odbc.SQLAllocHandle(handleType, inputHandle, handle);
  return retcode, handle[0]
end

function _M.covertAttrValue(value_arg)
  local value = nil
  local stringLength = 0
  if type(value_arg) == 'string' then
    value = ffi.new("char[?]", #value_arg)
    stringLength = #value_arg
  elseif type(value_arg) == 'number' then
    value = ffi.cast('SQLPOINTER', value_arg)
  end

  return value, stringLength
end

function _M.SQLSetEnvAttr(henv, attribute, value)
  local value, stringLength = _M.covertAttrValue(value)
  return odbc.SQLSetEnvAttr(henv, attribute, value, stringLength);
end

function _M.SQLSetConnectAttr(hdbc, attribute, value_arg)
  local value, stringLength = self.covertAttrValue(value)
  return odbc.SQLSetConnectAttr(hdbc, attribute, value, stringLength);
end

function _M.SQLSetStmtAttr(hstmt, attribute, value_arg)
  local value, stringLength = self.covertAttrValue(value)
  return odbc.SQLSetStmtAttr(hstmt, attribute, value, stringLength);
end

function _M.SQLDriverConnect(hdbc, hwnd, szConnStrIn, fDriverCompletion)
  local szConnStrIn_ptr = ffi.new("char[?]", #szConnStrIn)
  ffi.copy(szConnStrIn_ptr, szConnStrIn)

  local len = ffi.new(smallint_type)
  local retcode = odbc.SQLDriverConnect(hdbc, hwnd, szConnStrIn_ptr, #szConnStrIn, szConnStrOut_ptr, MAX_NAME_LEN, len, fDriverCompletion)
  return retcode, ffi.string(szConnStrOut_ptr, len[0])
end

function _M.SQLPrepare(hstmt, sql)
  local sql_ptr = ffi.new("char[?]", #sql)
  ffi.copy(sql_ptr, sql)
  return odbc.SQLPrepare(hstmt, sql_ptr, #sql);
end

function _M.SQLExecute(hstmt, timeout)
  if timeout ~= nil then
    local timeout = tonumber(timeout) or 5
    _M.SQLSetStmtAttr(hstmt, self.SQL_QUERY_TIMEOUT, timeout, 0)
  end
  return odbc.SQLExecute(hstmt)
end

function _M.SQLExecuteAsync(hdbc, hstmt, timeout)
  local timeout = tonumber(timeout) or 5
  local fd = nil
  local retcode = nil
  local status = ffi.new(integer_type)
  repeat
    retcode = odbc.SQLExecuteAsync(hstmt, status)
    if retcode ~= 0 then
      if fd == nil then
        local ret = nil
        ret, fd = _M.SQLGetAsyncConnFd(hdbc)
        if ret ~= 0 then
          return retcode
        end
      end

      local ret = ngx_odbc.wait(fd, timeout)
      if ret == 1 then
        _M.SQLDisconnect(hdbc)
        return -1
      end
    end
  until (retcode == 0)

  return retcode
end

function _M.SQLGetAsyncConnFd(hdbc)
  local fd = ffi.new(integer_type)
  local retcode =  odbc.SQLGetAsyncConnFd(hdbc, fd);
  return retcode, fd[0]
end

function _M.SQLExecDirect(hstmt, sql, timeout)
  if timeout ~= nil then
    local timeout = tonumber(timeout) or 5
    _M.SQLSetStmtAttr(hstmt, self.SQL_QUERY_TIMEOUT, timeout, 0)
  end
  local sql_ptr = ffi.new("char[?]", #sql)
  ffi.copy(sql_ptr, sql)
  return odbc.SQLExecDirect(hstmt, sql_ptr, #sql)
end

function _M.SQLBindCol(hstmt, columnNumber, targetType, bufferLength)
  local res = ffi.new(integer_type)
  local col = nil
  if targetType == self.SQL_C_LONG then
    col = ffi.new(integer_type)
    bufferLength = ffi.sizeof(integer_type)
  elseif targetType == self.SQL_C_CHAR then
    col = ffi.new("char[?]", bufferLength)
  end
  local retcode = odbc.SQLBindCol(hstmt, columnNumber, targetType, col, bufferLength, res);
  return retcode, col, res
end

function _M.SQLFetch(hstmt)
  return odbc.SQLFetch(hstmt)
end

function _M.SQLFreeHandle(handleType, handle)
  return odbc.SQLFreeHandle(handleType, handle);
end

function _M.SQLDisconnect(hdbc)
  return odbc.SQLDisconnect(hdbc);
end

return setmetatable(self, mt)
