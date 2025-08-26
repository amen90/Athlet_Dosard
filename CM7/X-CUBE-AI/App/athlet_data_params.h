/**
  ******************************************************************************
  * @file    athlet_data_params.h
  * @author  AST Embedded Analytics Research Platform
  * @date    2025-08-26T00:21:38+0200
  * @brief   AI Tool Automatic Code Generator for Embedded NN computing
  ******************************************************************************
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  ******************************************************************************
  */

#ifndef ATHLET_DATA_PARAMS_H
#define ATHLET_DATA_PARAMS_H

#include "ai_platform.h"

/*
#define AI_ATHLET_DATA_WEIGHTS_PARAMS \
  (AI_HANDLE_PTR(&ai_athlet_data_weights_params[1]))
*/

#define AI_ATHLET_DATA_CONFIG               (NULL)


#define AI_ATHLET_DATA_ACTIVATIONS_SIZES \
  { 192, }
#define AI_ATHLET_DATA_ACTIVATIONS_SIZE     (192)
#define AI_ATHLET_DATA_ACTIVATIONS_COUNT    (1)
#define AI_ATHLET_DATA_ACTIVATION_1_SIZE    (192)



#define AI_ATHLET_DATA_WEIGHTS_SIZES \
  { 2948, }
#define AI_ATHLET_DATA_WEIGHTS_SIZE         (2948)
#define AI_ATHLET_DATA_WEIGHTS_COUNT        (1)
#define AI_ATHLET_DATA_WEIGHT_1_SIZE        (2948)



#define AI_ATHLET_DATA_ACTIVATIONS_TABLE_GET() \
  (&g_athlet_activations_table[1])

extern ai_handle g_athlet_activations_table[1 + 2];



#define AI_ATHLET_DATA_WEIGHTS_TABLE_GET() \
  (&g_athlet_weights_table[1])

extern ai_handle g_athlet_weights_table[1 + 2];


#endif    /* ATHLET_DATA_PARAMS_H */
