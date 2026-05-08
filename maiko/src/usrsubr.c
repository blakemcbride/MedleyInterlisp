/* $Id: usrsubr.c,v 1.3 1999/05/31 23:35:46 sybalsky Exp $ (C) Copyright Venue, All Rights Reserved
 */

/************************************************************************/
/*									*/
/*	(C) Copyright 1989-95 Venue. All Rights Reserved.		*/
/*	Manufactured in the United States of America.			*/
/*									*/
/************************************************************************/

#include "version.h"

#include <stdio.h>

#include "lispemul.h"
#include "lsptypes.h"
#include "arith.h"
#include "subrs.h"
#include "usrsubrdefs.h"

/** User defined subrs here.  Do NOT attempt to use this unless you FULLY
    understand the dependencies of the LDE architecture.                 **/

int UserSubr(int user_subr_index, int num_args, unsigned *args) {
  int result = 0;

  switch (user_subr_index) {
    case user_subr_SAMPLE_USER_SUBR:
      printf("sample UFN\n");
      result = args[0];
      break;

    case user_subr_BLOCK_UNTIL_EVENT: {
      int max_ms;
      if (num_args < 1) { result = NIL_PTR; break; }
      N_GETNUMBER(args[0], max_ms, bue_badarg);
      result = block_until_event(max_ms);
      break;
    bue_badarg:
      result = NIL_PTR;
      break;
    }

    case user_subr_DSP_DESIRED_W:
      result = S_POSITIVE | (0xFFFF & desired_displaywidth);
      break;

    case user_subr_DSP_DESIRED_H:
      result = S_POSITIVE | (0xFFFF & desired_displayheight);
      break;

    case user_subr_DSP_COMMIT_RESIZE: {
      int new_w, new_h;
      if (num_args < 2) { result = NIL_PTR; break; }
      N_GETNUMBER(args[0], new_w, cr_badarg);
      N_GETNUMBER(args[1], new_h, cr_badarg);
      result = dsp_commit_resize(new_w, new_h);
      break;
    cr_badarg:
      result = NIL_PTR;
      break;
    }

  default:
      return (-1); /* DO UFN */
  }

  return (result);
}
