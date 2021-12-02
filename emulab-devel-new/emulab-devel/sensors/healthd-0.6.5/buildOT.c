/*-
 * Copyright (c) 1999-2000 James E. Housley <jim@thehousleys.net>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	$Id: buildOT.c,v 1.1 2001-12-05 18:45:07 kwebb Exp $
 */

#include <stdio.h>
#include <stdlib.h>

int main(void);

int
main(void) {
  int x;

  printf("/*\n * This file was generated by buildOT\n * PLEASE DON'T HAND EDIT!!!\n");
  printf(" * $Id: buildOT.c,v 1.1 2001-12-05 18:45:07 kwebb Exp $\n */\n\n");
  printf("#undef NULL\n#define NULL 0x00\n\n");
  printf("static struct OptionInfo optionTable[] = {\n");
  
  /*
   * Temps
   */
  for (x=0; x<3; x++) {
    printf("  { Temp%d_active,\n", x);
    printf("    YesNo,\n");
    printf("    \"[yes|no]\",\n");
    printf("    \"Temperature #%d\",\n", x);
    printf("    \"Temp%d_active\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"T%d_ACT\",\n", x+1);
    printf("    &active[Temp%d_active/6] },\n", x);
    printf("\n");
    printf("  { Temp%d_label,\n", x);
    printf("    String,\n");
    printf("    \"label\",\n");
    printf("    \"Temperature #%d\",\n", x);
    printf("    \"Temp%d_label\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"T%d_LBL\",\n", x+1);
    printf("    &label[Temp%d_label/6]},\n", x);
    printf("\n");
    printf("  { Temp%d_min,\n", x);
    printf("    Float,\n");
    printf("    \"min\",\n");
    printf("    \"Temperature #%d\",\n", x);
    printf("    \"Temp%d_min\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"T%d_MIN\",\n", x+1);
    printf("    &min_val[Temp%d_min/6]},\n", x);
    printf("\n");
    printf("  { Temp%d_max,\n", x);
    printf("    Float,\n");
    printf("    \"min\",\n");
    printf("    \"Temperature #%d\",\n", x);
    printf("    \"Temp%d_max\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"T%d_MAX\",\n", x+1);
    printf("    &max_val[Temp%d_max/6]},\n", x);
    printf("\n");
    printf("  { Temp%d_doWarn,\n", x);
    printf("    YesNo,\n");
    printf("    \"[yes|no]\",\n");
    printf("    \"Temperature #%d\",\n", x);
    printf("    \"Temp%d_doWarn\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("#ifdef FULL_CFG\n");
    printf("    \"T%d_DOW\",\n", x+1);
    printf("#else /* !FULL_CFG */\n");
    printf("    NULL,\n");
    printf("#endif /* !FULL_CFG */\n");
    printf("    &doWarn[Temp%d_doWarn/6]},\n", x);
    printf("\n");
    printf("  { Temp%d_doFail,\n", x);
    printf("    YesNo,\n");
    printf("    \"[yes|no]\",\n");
    printf("    \"Temperature #%d\",\n", x);
    printf("    \"Temp%d_doFail\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("#ifdef FULL_CFG\n");
    printf("    \"T%d_DOF\",\n", x+1);
    printf("#else /* !FULL_CFG */\n");
    printf("    NULL,\n");
    printf("#endif /* !FULL_CFG */\n");
    printf("    &doFail[Temp%d_doFail/6]},\n", x);
    printf("\n");
  }

  /*
   * Fan Speeds
   */
  for (x=0; x<3; x++) {
    printf("  { Fan%d_active,\n", x);
    printf("    YesNo,\n");
    printf("    \"[yes|no]\",\n");
    printf("    \"Fan Speed #%d\",\n", x);
    printf("    \"Fan%d_active\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"F%d_ACT\",\n", x+1);
    printf("    &active[Fan%d_active/6] },\n", x);
    printf("\n");
    printf("  { Fan%d_label,\n", x);
    printf("    String,\n");
    printf("    \"label\",\n");
    printf("    \"Fan Speed #%d\",\n", x);
    printf("    \"Fan%d_label\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"F%d_LBL\",\n", x+1);
    printf("    &label[Fan%d_label/6]},\n", x);
    printf("\n");
    printf("  { Fan%d_min,\n", x);
    printf("    Numeric,\n");
    printf("    \"min\",\n");
    printf("    \"Fan Speed #%d\",\n", x);
    printf("    \"Fan%d_min\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"F%d_MIN\",\n", x+1);
    printf("    &min_val[Fan%d_min/6]},\n", x);
    printf("\n");
    printf("  { Fan%d_max,\n", x);
    printf("    Numeric,\n");
    printf("    \"min\",\n");
    printf("    \"Fan Speed #%d\",\n", x);
    printf("    \"Fan%d_max\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"F%d_MAX\",\n", x+1);
    printf("    &max_val[Fan%d_max/6]},\n", x);
    printf("\n");
    printf("  { Fan%d_doWarn,\n", x);
    printf("    YesNo,\n");
    printf("    \"[yes|no]\",\n");
    printf("    \"Fan Speed #%d\",\n", x);
    printf("    \"Fan%d_doWarn\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("#ifdef FULL_CFG\n");
    printf("    \"F%d_DOW\",\n", x+1);
    printf("#else /* !FULL_CFG */\n");
    printf("    NULL,\n");
    printf("#endif /* !FULL_CFG */\n");
    printf("    &doWarn[Fan%d_doWarn/6]},\n", x);
    printf("\n");
    printf("  { Fan%d_doFail,\n", x);
    printf("    YesNo,\n");
    printf("    \"[yes|no]\",\n");
    printf("    \"Fan Speed #%d\",\n", x);
    printf("    \"Fan%d_doFail\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("#ifdef FULL_CFG\n");
    printf("    \"F%d_DOF\",\n", x+1);
    printf("#else /* !FULL_CFG */\n");
    printf("    NULL,\n");
    printf("#endif /* !FULL_CFG */\n");
    printf("    &doFail[Fan%d_doFail/6]},\n", x);
    printf("\n");
  }

  /*
   * Voltagess
   */
  for (x=0; x<7; x++) {
    printf("  { Volt%d_active,\n", x);
    printf("    YesNo,\n");
    printf("    \"[yes|no]\",\n");
    printf("    \"Voltage #%d\",\n", x);
    printf("    \"Volt%d_active\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"V%d_ACT\",\n", x+1);
    printf("    &active[Volt%d_active/6] },\n", x);
    printf("\n");
    printf("  { Volt%d_label,\n", x);
    printf("    String,\n");
    printf("    \"label\",\n");
    printf("    \"Voltage #%d\",\n", x);
    printf("    \"Volt%d_label\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"V%d_LBL\",\n", x+1);
    printf("    &label[Volt%d_label/6]},\n", x);
    printf("\n");
    printf("  { Volt%d_min,\n", x);
    printf("    Float,\n");
    printf("    \"min\",\n");
    printf("    \"Voltage #%d\",\n", x);
    printf("    \"Volt%d_min\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"V%d_MIN\",\n", x+1);
    printf("    &min_val[Volt%d_min/6]},\n", x);
    printf("\n");
    printf("  { Volt%d_max,\n", x);
    printf("    Float,\n");
    printf("    \"min\",\n");
    printf("    \"Voltage #%d\",\n", x);
    printf("    \"Volt%d_max\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("    \"V%d_MAX\",\n", x+1);
    printf("    &max_val[Volt%d_max/6]},\n", x);
    printf("\n");
    printf("  { Volt%d_doWarn,\n", x);
    printf("    YesNo,\n");
    printf("    \"[yes|no]\",\n");
    printf("    \"Voltage #%d\",\n", x);
    printf("    \"Volt%d_doWarn\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("#ifdef FULL_CFG\n");
    printf("    \"V%d_DOW\",\n", x+1);
    printf("#else /* !FULL_CFG */\n");
    printf("    NULL,\n");
    printf("#endif /* !FULL_CFG */\n");
    printf("    &doWarn[Volt%d_doWarn/6]},\n", x);
    printf("\n");
    printf("  { Volt%d_doFail,\n", x);
    printf("    YesNo,\n");
    printf("    \"[yes|no]\",\n");
    printf("    \"Voltage #%d\",\n", x);
    printf("    \"Volt%d_doFail\",\n", x);
    printf("    NULL,\n");
    printf("    NULL,\n");
    printf("#ifdef FULL_CFG\n");
    printf("    \"V%d_DOF\",\n", x+1);
    printf("#else /* !FULL_CFG */\n");
    printf("    NULL,\n");
    printf("#endif /* !FULL_CFG */\n");
    printf("    &doFail[Volt%d_doFail/6]},\n", x);
    printf("\n");
  }

  printf("  { Temp_warn,\n");
  printf("    String,\n");
  printf("    \"Command\",\n");
  printf("    \"Command#2\",\n");
  printf("    \"Temp_warn\",\n");
  printf("    NULL,\n");
  printf("    NULL,\n");
  printf("#ifdef FULL_CFG\n");
  printf("    \"TWarn\",\n");
  printf("#else /* !FULL_CFG */\n");
  printf("    NULL,\n");
  printf("#endif /* !FULL_CFG */\n");
  printf("    NULL },\n");
  printf("\n");
  printf("  { Temp_fail,\n");
  printf("    String,\n");
  printf("    \"Command\",\n");
  printf("    \"Command#2\",\n");
  printf("    \"Temp_fail\",\n");
  printf("    NULL,\n");
  printf("    NULL,\n");
  printf("#ifdef FULL_CFG\n");
  printf("    \"TFail\",\n");
  printf("#else /* !FULL_CFG */\n");
  printf("    NULL,\n");
  printf("#endif /* !FULL_CFG */\n");
  printf("    NULL },\n");
  printf("\n");
  printf("  { Fan_warn,\n");
  printf("    String,\n");
  printf("    \"Command\",\n");
  printf("    \"Command#2\",\n");
  printf("    \"Fan_warn\",\n");
  printf("    NULL,\n");
  printf("    NULL,\n");
  printf("#ifdef FULL_CFG\n");
  printf("    \"FWarn\",\n");
  printf("#else /* !FULL_CFG */\n");
  printf("    NULL,\n");
  printf("#endif /* !FULL_CFG */\n");
  printf("    NULL },\n");
  printf("\n");
  printf("  { Fan_fail,\n");
  printf("    String,\n");
  printf("    \"Command\",\n");
  printf("    \"Command#2\",\n");
  printf("    \"Fan_fail\",\n");
  printf("    NULL,\n");
  printf("    NULL,\n");
  printf("#ifdef FULL_CFG\n");
  printf("    \"FFail\",\n");
  printf("#else /* !FULL_CFG */\n");
  printf("    NULL,\n");
  printf("#endif /* !FULL_CFG */\n");
  printf("    NULL },\n");
  printf("\n");
  printf("  { Volt_warn,\n");
  printf("    String,\n");
  printf("    \"Command\",\n");
  printf("    \"Command#2\",\n");
  printf("    \"Volt_warn\",\n");
  printf("    NULL,\n");
  printf("    NULL,\n");
  printf("#ifdef FULL_CFG\n");
  printf("    \"VWarn\",\n");
  printf("#else /* !FULL_CFG */\n");
  printf("    NULL,\n");
  printf("#endif /* !FULL_CFG */\n");
  printf("    NULL },\n");
  printf("\n");
  printf("  { Volt_fail,\n");
  printf("    String,\n");
  printf("    \"Command\",\n");
  printf("    \"Command#2\",\n");
  printf("    \"Volt_fail\",\n");
  printf("    NULL,\n");
  printf("    NULL,\n");
  printf("#ifdef FULL_CFG\n");
  printf("    \"VFail\",\n");
  printf("#else /* !FULL_CFG */\n");
  printf("    NULL,\n");
  printf("#endif /* !FULL_CFG */\n");
  printf("    NULL }\n");
  printf("};\n");

  exit(0);
}