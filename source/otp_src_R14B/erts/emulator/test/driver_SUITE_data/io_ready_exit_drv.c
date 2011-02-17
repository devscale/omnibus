/* ``The contents of this file are subject to the Erlang Public License,
 * Version 1.1, (the "License"); you may not use this file except in
 * compliance with the License. You should have received a copy of the
 * Erlang Public License along with this software. If not, it can be
 * retrieved via the world wide web at http://www.erlang.org/.
 * 
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.
 * 
 * The Initial Developer of the Original Code is Ericsson Utvecklings AB.
 * Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
 * AB. All Rights Reserved.''
 * 
 *     $Id$
 */

#ifndef UNIX
#if !defined(__WIN32__) && !defined(VXWORKS)
#define UNIX 1
#endif
#endif

#include <stdio.h>
#include <string.h>
#ifdef UNIX
#include <unistd.h>
#endif
#include "erl_driver.h"

typedef struct {
    ErlDrvPort port;
    int fds[2];
} IOReadyExitDrvData;

static ErlDrvData io_ready_exit_drv_start(ErlDrvPort, char *);
static void io_ready_exit_drv_stop(ErlDrvData);
static void io_ready_exit_ready_input(ErlDrvData, ErlDrvEvent);
static void io_ready_exit_ready_output(ErlDrvData, ErlDrvEvent);
static void io_ready_exit_drv_output(ErlDrvData, char *, int);
static void io_ready_exit_drv_finish(void);
static int io_ready_exit_drv_control(ErlDrvData, unsigned int,
				   char *, int, char **, int);

static ErlDrvEntry io_ready_exit_drv_entry = { 
    NULL, /* init */
    io_ready_exit_drv_start,
    io_ready_exit_drv_stop,
    NULL /* output */,
    io_ready_exit_ready_input,
    io_ready_exit_ready_output,
    "io_ready_exit_drv",
    NULL /* finish */,
    NULL, /* handle */
    io_ready_exit_drv_control,
    NULL, /* timeout */
    NULL, /* outputv */
    NULL  /* ready_async */
};

/* -------------------------------------------------------------------------
** Entry functions
**/

DRIVER_INIT(io_ready_exit_drv)
{
    return &io_ready_exit_drv_entry;
}

static ErlDrvData
io_ready_exit_drv_start(ErlDrvPort port, char *command) {
    IOReadyExitDrvData *oeddp = driver_alloc(sizeof(IOReadyExitDrvData));
    oeddp->port = port;
    oeddp->fds[0] = -1;
    oeddp->fds[1] = -1;
    return (ErlDrvData) oeddp;
}

static void
io_ready_exit_drv_stop(ErlDrvData drv_data) {
    IOReadyExitDrvData *oeddp = (IOReadyExitDrvData *) drv_data;
#ifdef UNIX
    if (oeddp->fds[0] >= 0) {
	driver_select(oeddp->port,
		      (ErlDrvEvent) oeddp->fds[0],
		      DO_READ|DO_WRITE,
		      0);
	close(oeddp->fds[0]);
    }
    if (oeddp->fds[1] >= 0)
	close(oeddp->fds[1]);
#endif
    driver_free((void *) oeddp);
}


static void
io_ready_exit_ready_output(ErlDrvData drv_data, ErlDrvEvent event)
{
    IOReadyExitDrvData *oeddp = (IOReadyExitDrvData *) drv_data;
    driver_failure_atom(oeddp->port, "ready_output_driver_failure");
}

static void
io_ready_exit_ready_input(ErlDrvData drv_data, ErlDrvEvent event)
{
    IOReadyExitDrvData *oeddp = (IOReadyExitDrvData *) drv_data;
    driver_failure_atom(oeddp->port, "ready_input_driver_failure");
}

static int
io_ready_exit_drv_control(ErlDrvData drv_data,
			  unsigned int command,
			  char *buf, int len,
			  char **rbuf, int rlen)
{
    char *abuf;
    char *res_str;
    int res_len;
    IOReadyExitDrvData *oeddp = (IOReadyExitDrvData *) drv_data;
#ifndef UNIX
    res_str = "nyiftos";
#else
    if (pipe(oeddp->fds) < 0) {
	res_str = "pipe failed";
    }
    else {
	res_str = "ok";
	write(oeddp->fds[1], "!", 1);
	driver_select(oeddp->port,
		      (ErlDrvEvent) oeddp->fds[0],
		      DO_READ|DO_WRITE,
		      1);
    }
#endif
    res_len = strlen(res_str);
    if (res_len > rlen) {
	abuf = driver_alloc(sizeof(char)*res_len);
	if (!abuf)
	    return 0;
	*rbuf = abuf;
    }

    memcpy((void *) *rbuf, (void *) res_str, res_len);

    return res_len;
}



