/*
 * Copyright (C) 
 */


#ifndef DDEBUG
#define DDEBUG 0
#endif
#include "ddebug.h"


#include <lauxlib.h>
#include "ngx_http_lua_api.h"
#include "ngx_http_lua_util.h"

static void ngx_http_lua_sleep_cleanup(void *data);
static int ngx_http_lua_odbc_wait(lua_State *L);
static void ngx_http_lua_odbc_wait_handler(ngx_event_t *ev);
static void ngx_http_lua_odbc_wait_cleanup(void *data);
static ngx_int_t ngx_http_lua_odbc_wait_resume(ngx_http_request_t *r);
static ngx_int_t ngx_http_lua_odbc_wait_sleep_resume(ngx_http_request_t *r);
static ngx_int_t ngx_http_lua_odbc_wait_resume_helper(ngx_http_request_t *r, int ret);

ngx_module_t ngx_http_lua_odbc_module;
static ngx_int_t ngx_http_lua_odbc_init(ngx_conf_t *cf);
static int ngx_http_lua_odbc_create_module(lua_State * L);

static ngx_http_module_t ngx_http_lua_odbc_ctx = {
    NULL,                           /* preconfiguration */
    ngx_http_lua_odbc_init,     /* postconfiguration */
    NULL,                           /* create main configuration */
    NULL,                           /* init main configuration */
    NULL,                           /* create server configuration */
    NULL,                           /* merge server configuration */
    NULL,                           /* create location configuration */
    NULL                            /* merge location configuration */
};


ngx_module_t ngx_http_lua_odbc_module = {
    NGX_MODULE_V1,
    &ngx_http_lua_odbc_ctx,  /* module context */
    NULL,                        /* module directives */
    NGX_HTTP_MODULE,             /* module type */
    NULL,                        /* init master */
    NULL,                        /* init module */
    NULL,                        /* init process */
    NULL,                        /* init thread */
    NULL,                        /* exit thread */
    NULL,                        /* exit process */
    NULL,                        /* exit master */
    NGX_MODULE_V1_PADDING
};

static ngx_int_t
ngx_http_lua_odbc_init(ngx_conf_t *cf)
{
    if (ngx_http_lua_add_package_preload(cf, "ngx.odbc",
                                         ngx_http_lua_odbc_create_module)
        != NGX_OK)
    {
        return NGX_ERROR;
    }

    return NGX_OK;
}


static int
ngx_http_lua_odbc_create_module(lua_State * L)
{
    lua_createtable(L, 0, 1);

    lua_pushcfunction(L, ngx_http_lua_odbc_wait);
    lua_setfield(L, -2, "wait");
    return 1;
}

static int
ngx_http_lua_odbc_wait(lua_State *L)
{
  int                          n;
  ngx_int_t                    delay = -1; /* in msec */
  ngx_socket_t                fd;
  ngx_http_request_t          *r;
  ngx_connection_t  *c;
  ngx_http_lua_ctx_t          *ctx;
  ngx_http_lua_co_ctx_t       *coctx;

  n = lua_gettop(L);
  if (n != 1 && n != 2) {
    return luaL_error(L, "attempt to pass %d arguments, but accepted 1", n);
  }

  r = ngx_http_lua_get_req(L);
  if (r == NULL) {
    return luaL_error(L, "no request found");
  }

  fd = (ngx_socket_t) (luaL_checknumber(L, 1));
  if (fd < 0) {
    return luaL_error(L, "invalid fd \"%d\"", fd);
  }

  if (n == 2) {
    delay = (ngx_int_t) (luaL_checknumber(L, 2) * 1000);

    if (delay < 0) {
      return luaL_error(L, "invalid sleep duration \"%d\"", delay);
    }
  }

  ctx = ngx_http_get_module_ctx(r, ngx_http_lua_module);
  if (ctx == NULL) {
    return luaL_error(L, "no request ctx found");
  }

  ngx_http_lua_check_context(L, ctx, NGX_HTTP_LUA_CONTEXT_REWRITE
                             | NGX_HTTP_LUA_CONTEXT_ACCESS
                             | NGX_HTTP_LUA_CONTEXT_CONTENT
                             | NGX_HTTP_LUA_CONTEXT_TIMER
                             | NGX_HTTP_LUA_CONTEXT_SSL_CERT
                             | NGX_HTTP_LUA_CONTEXT_SSL_SESS_FETCH);

  coctx = ctx->cur_co_ctx;
  if (coctx == NULL) {
    return luaL_error(L, "no co ctx found");
  }

  ngx_http_lua_cleanup_pending_operation(coctx);
  coctx->cleanup = ngx_http_lua_odbc_wait_cleanup;
  coctx->data = r;

  c = ngx_get_connection(fd, r->connection->log);
  c->read->handler = ngx_http_lua_odbc_wait_handler;
  c->data = coctx;
  c->read->log = r->connection->log;
  c->write->handler = NULL;

  ngx_add_event(c->read, NGX_READ_EVENT, 0);

  coctx->sleep.data = c;
  if (n == 2) {
    coctx->sleep.handler = ngx_http_lua_odbc_wait_handler;
    coctx->sleep.log = r->connection->log;

    if (delay == 0) {
#ifdef HAVE_POSTED_DELAYED_EVENTS_PATCH
      dd("posting 0 sec sleep event to head of delayed queue");

      coctx->sleep.delayed = 1;
      ngx_post_event(&coctx->sleep, &ngx_posted_delayed_events);
#else
      ngx_log_error(NGX_LOG_WARN, r->connection->log, 0, "ngx.sleep(0)"
                    " called without delayed events patch, this will"
                    " hurt performance");
      ngx_add_timer(&coctx->sleep, (ngx_msec_t) delay);
#endif
    } else {
      dd("adding timer with delay %lu ms, r:%.*s", (unsigned long) delay,
         (int) r->uri.len, r->uri.data);

      ngx_add_timer(&coctx->sleep, (ngx_msec_t) delay);
    }

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "lua ready to sleep for %d ms", delay);
  }

  return lua_yield(L, 0);
}

void
ngx_http_lua_odbc_wait_handler(ngx_event_t *ev)
{
  ngx_http_request_t      *r;
  ngx_connection_t  *c;
  ngx_http_lua_ctx_t          *ctx;
  ngx_http_log_ctx_t      *log_ctx;
  ngx_http_lua_co_ctx_t   *coctx;

  c = ev->data;
  coctx = c->data;
  r = coctx->data;

  ngx_del_event(c->read, NGX_READ_EVENT, 0);
  ngx_free_connection(c);
  c = r->connection;

  if (ev != &coctx->sleep) {
    ngx_http_lua_sleep_cleanup(coctx)
    ngx_log_debug2(NGX_LOG_DEBUG_HTTP, c->log, 0,
                   "read event triggered: \"%V?%V\"", &r->uri, &r->args);
  } else {
    ngx_log_debug2(NGX_LOG_DEBUG_HTTP, c->log, 0,
                   "lua sleep timer expired: \"%V?%V\"", &r->uri, &r->args);
  }

  ctx = ngx_http_get_module_ctx(r, ngx_http_lua_module);
  if (ctx == NULL) {
    return;
  }

  if (c->fd != (ngx_socket_t) -1) {  /* not a fake connection */
    log_ctx = c->log->data;
    log_ctx->current_request = r;
  }

  coctx->cleanup = NULL;
  ctx->cur_co_ctx = coctx;

  if (ctx->entered_content_phase) {
    if (ev != &coctx->sleep) {
      (void) ngx_http_lua_odbc_wait_resume(r);
    } else {
      (void) ngx_http_lua_odbc_wait_sleep_resume(r);
    }
  } else {
    if (ev != &coctx->sleep) {
      ctx->resume_handler = ngx_http_lua_odbc_wait_resume;
    } else {
      ctx->resume_handler = ngx_http_lua_odbc_wait_sleep_resume;
    }

    ngx_http_core_run_phases(r);
  }

  ngx_http_run_posted_requests(c);
}

static void
ngx_http_lua_odbc_wait_cleanup(void *data)
{
  ngx_http_lua_co_ctx_t          *coctx = data;
  ngx_connection_t  *c;

  c = coctx->sleep.data;

  ngx_del_event(c->read, NGX_READ_EVENT, 0);
  ngx_free_connection(c);

  ngx_http_lua_sleep_cleanup(data);
}

static void
ngx_http_lua_sleep_cleanup(void *data)
{
    ngx_http_lua_co_ctx_t          *coctx = data;

    if (coctx->sleep.timer_set) {
        ngx_log_debug0(NGX_LOG_DEBUG_HTTP, ngx_cycle->log, 0,
                       "lua clean up the timer for pending ngx.sleep");

        ngx_del_timer(&coctx->sleep);
    }

#ifdef HAVE_POSTED_DELAYED_EVENTS_PATCH
    if (coctx->sleep.posted) {
        ngx_log_debug0(NGX_LOG_DEBUG_HTTP, ngx_cycle->log, 0,
                       "lua clean up the posted event for pending ngx.sleep");

        ngx_delete_posted_event(&coctx->sleep);
    }
#endif
}

static ngx_int_t
ngx_http_lua_odbc_wait_sleep_resume(ngx_http_request_t *r)
{
  return ngx_http_lua_odbc_wait_resume_helper(r, 1);
}

static ngx_int_t
ngx_http_lua_odbc_wait_resume(ngx_http_request_t *r)
{
  return ngx_http_lua_odbc_wait_resume_helper(r, 0);
}

static ngx_int_t
ngx_http_lua_odbc_wait_resume_helper(ngx_http_request_t *r, int ret)
{
    lua_State                   *vm;
    ngx_connection_t            *c;
    ngx_int_t                    rc;
    ngx_uint_t                   nreqs;
    ngx_http_lua_ctx_t          *ctx;

    ctx = ngx_http_get_module_ctx(r, ngx_http_lua_module);
    if (ctx == NULL) {
        return NGX_ERROR;
    }

    ctx->resume_handler = ngx_http_lua_wev_handler;

    c = r->connection;
    vm = ngx_http_lua_get_lua_vm(r, ctx);
    nreqs = c->requests;

    lua_pushnumber(ctx->cur_co_ctx->co, ret);

    rc = ngx_http_lua_run_thread(vm, r, ctx, 1);

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "lua run thread returned %d", rc);

    if (rc == NGX_AGAIN) {
        return ngx_http_lua_run_posted_threads(c, vm, r, ctx, nreqs);
    }

    if (rc == NGX_DONE) {
        ngx_http_lua_finalize_request(r, NGX_DONE);
        return ngx_http_lua_run_posted_threads(c, vm, r, ctx, nreqs);
    }

    if (ctx->entered_content_phase) {
        ngx_http_lua_finalize_request(r, rc);
        return NGX_DONE;
    }

    return rc;
}
