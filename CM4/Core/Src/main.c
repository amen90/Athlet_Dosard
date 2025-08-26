/* USER CODE BEGIN Header */
/**ttoo
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "max30100_for_stm32_hal.h" // Your MAX30100 library
#include "aes.h"
#include <stdio.h>   // For snprintf
#include <string.h>  // For strlen
#include <math.h>    // For fabs, log for more advanced SpO2 if needed
#include "cmsis_os.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

#ifndef HSEM_ID_0
#define HSEM_ID_0 (0U) /* HW semaphore 0*/
#endif

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
ADC_HandleTypeDef hadc1;

I2C_HandleTypeDef hi2c1;
DMA_HandleTypeDef hdma_i2c1_rx;

TIM_HandleTypeDef htim6;

UART_HandleTypeDef huart3;

// Buffer for heart rate calculation (e.g., 8 * 16 samples = 128 samples)
#define HR_CALC_BUFFER_SIZE (MAX30100_SAMPLES_PER_READ * 8)
static uint16_t hr_ir_sample_buffer[HR_CALC_BUFFER_SIZE];
static uint16_t hr_red_sample_buffer[HR_CALC_BUFFER_SIZE];
static uint16_t hr_buffer_idx = 0;
static uint8_t hr_buffer_full = 0;

// Sampling rate (must match MAX30100 configuration)
const float ppg_sample_rate_hz = 100.0f; // Assuming 100Hz from MAX30100_SPO2_SAMPLERATE_100HZ

/* Definitions for defaultTask */
osThreadId_t defaultTaskHandle;
const osThreadAttr_t defaultTask_attributes = {
  .name = "defaultTask",
  .stack_size = 128 * 4,
  .priority = (osPriority_t) osPriorityNormal,
};
/* USER CODE BEGIN PV */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
static void MX_GPIO_Init(void);
static void MX_DMA_Init(void);
static void MX_ADC1_Init(void);
static void MX_I2C1_Init(void);
static void MX_TIM6_Init(void);
static void MX_USART3_UART_Init(void);
void StartDefaultTask(void *argument);

void processMAX30100Data(void);
void readLM35Temperature(void); // Specific function for LM35
float calculateDC(uint16_t *samples, uint16_t size);
float calculateAC(uint16_t *samples, uint16_t size);
int countPeaks(uint16_t *samples, uint16_t size, float threshold, float min_peak_distance_samples);

// AES-CTR helper for securing UART frames to ESP32
#define ENABLE_AES_UART 1
static const uint8_t kAesKey128[16] = { 0x2b,0x7e,0x15,0x16,0x28,0xae,0xd2,0xa6,0xab,0xf7,0x15,0x88,0x09,0xcf,0x4f,0x3c };
static uint32_t g_uart_iv_counter = 1;

static void secure_uart_send(const uint8_t* data, uint16_t len)
{
#if ENABLE_AES_UART
  struct AES_ctx ctx;
  uint8_t iv[AES_BLOCKLEN] = {0};
  // Simple monotonically increasing IV (last 4 bytes). Ensure ESP32 mirrors this.
  iv[12] = (uint8_t)((g_uart_iv_counter >> 24) & 0xFF);
  iv[13] = (uint8_t)((g_uart_iv_counter >> 16) & 0xFF);
  iv[14] = (uint8_t)((g_uart_iv_counter >> 8) & 0xFF);
  iv[15] = (uint8_t)(g_uart_iv_counter & 0xFF);

  // Prepare frame: [0xAA 0x55][IV(16)][LEN(2)][CIPHERTEXT]
  uint8_t header[2] = {0xAA, 0x55};
  uint8_t len_be[2] = { (uint8_t)(len >> 8), (uint8_t)(len & 0xFF) };
  // Copy plaintext to a mutable buffer
  uint8_t buf[256];
  uint16_t copy_len = (len > sizeof(buf)) ? sizeof(buf) : len; // truncate if oversized
  memcpy(buf, data, copy_len);

  AES_init_ctx_iv(&ctx, kAesKey128, iv);
  AES_CTR_xcrypt_buffer(&ctx, buf, copy_len);

  HAL_UART_Transmit(&huart3, header, sizeof(header), 100);
  HAL_UART_Transmit(&huart3, iv, sizeof(iv), 100);
  HAL_UART_Transmit(&huart3, len_be, sizeof(len_be), 100);
  HAL_UART_Transmit(&huart3, buf, copy_len, 200);

  g_uart_iv_counter++;
#else
  HAL_UART_Transmit(&huart3, (uint8_t*)data, len, 200);
#endif
}

/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

/* USER CODE BEGIN Boot_Mode_Sequence_1 */
  /*HW semaphore Clock enable*/
  __HAL_RCC_HSEM_CLK_ENABLE();
  /* Activate HSEM notification for Cortex-M4*/
  HAL_HSEM_ActivateNotification(__HAL_HSEM_SEMID_TO_MASK(HSEM_ID_0));
  /*
  Domain D2 goes to STOP mode (Cortex-M4 in deep-sleep) waiting for Cortex-M7 to
  perform system initialization (system clock config, external memory configuration.. )
  */
  HAL_PWREx_ClearPendingEvent();
  HAL_PWREx_EnterSTOPMode(PWR_MAINREGULATOR_ON, PWR_STOPENTRY_WFE, PWR_D2_DOMAIN);
  /* Clear HSEM flag */
  __HAL_HSEM_CLEAR_FLAG(__HAL_HSEM_SEMID_TO_MASK(HSEM_ID_0));

/* USER CODE END Boot_Mode_Sequence_1 */
  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_DMA_Init();
  MX_ADC1_Init();
  MX_I2C1_Init();
  MX_TIM6_Init();
  MX_USART3_UART_Init();
  /* USER CODE BEGIN 2 */

  /* USER CODE END 2 */

  /* Init scheduler */
  osKernelInitialize();

  /* USER CODE BEGIN RTOS_MUTEX */
  /* add mutexes, ... */
  /* USER CODE END RTOS_MUTEX */

  /* USER CODE BEGIN RTOS_SEMAPHORES */
  /* add semaphores, ... */
  /* USER CODE END RTOS_SEMAPHORES */

  /* USER CODE BEGIN RTOS_TIMERS */
  /* start timers, add new ones, ... */
  /* USER CODE END RTOS_TIMERS */

  /* USER CODE BEGIN RTOS_QUEUES */
  /* add queues, ... */
  /* USER CODE END RTOS_QUEUES */

  /* Create the thread(s) */
  /* creation of defaultTask */
  defaultTaskHandle = osThreadNew(StartDefaultTask, NULL, &defaultTask_attributes);

  /* USER CODE BEGIN RTOS_THREADS */
  /* add threads, ... */
  /* USER CODE END RTOS_THREADS */

  /* USER CODE BEGIN RTOS_EVENTS */
  /* add events, ... */
  /* USER CODE END RTOS_EVENTS */

  /* Start scheduler */
  osKernelStart();

  /* We should never get here as control is now taken by the scheduler */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  printf("System Initialized.\r\n");
    printf("LM35 on PC0 (ADC1_INP10), MAX30100 on I2C1, INT PB5.\r\n");

    /* Initialize MAX30100 */
    if (MAX30100_Init(&hi2c1) == HAL_OK) {
      printf("MAX30100 Initialized Successfully.\r\n");
      if (MAX30100_SetMode(MAX30100_MODE_SPO2_EN) == HAL_OK) {
          printf("MAX30100 Mode set to SpO2/HR.\r\n");
      } else {
          printf("Error: Failed to set MAX30100 mode.\r\n");
      }
    } else {
      printf("Error: MAX30100 Initialization Failed. Check connections.\r\n");
      while(1); // Halt on critical error
    }

    // --- Enable your EXTI interrupt for MAX30100 INT pin here ---
    // Example: HAL_NVIC_SetPriority(EXTIx_IRQn, 0, 0);
    //          HAL_NVIC_EnableIRQ(EXTIx_IRQn);

    uint32_t last_lm35_read_time = HAL_GetTick();
    uint32_t last_max_temp_read_time = HAL_GetTick();

    while (1)
    {
      if (max30100_new_data_available) {
        max30100_new_data_available = 0; // Clear the flag
        processMAX30100Data();
      }

      // Read LM35 temperature periodically
      if (HAL_GetTick() - last_lm35_read_time >= 5000) { // Every 5 seconds
        readLM35Temperature();
        last_lm35_read_time = HAL_GetTick();
      }

      // Read MAX30100 internal temperature periodically
      if (HAL_GetTick() - last_max_temp_read_time >= 10000) { // Every 10 seconds
          float sensor_temp_max30100;
          if(MAX30100_ReadTemperature(&sensor_temp_max30100) == HAL_OK) {
              char temp_buf[40];
              sprintf(temp_buf, "MAX30100 Die Temp: %.2f C\r\n", sensor_temp_max30100);
              secure_uart_send((uint8_t*)temp_buf, strlen(temp_buf));
          } else {
              printf("Warning: Failed to read MAX30100 temperature.\r\n");
          }
          last_max_temp_read_time = HAL_GetTick();
      }
      // __WFI(); // Optional: Wait for interrupt to save power if main loop has nothing else
    }
  }
void processMAX30100Data(void) {
    // Copy data from library's buffer to the heart rate calculation buffer
    for (int i = 0; i < MAX30100_SAMPLES_PER_READ; i++) {
        if (hr_buffer_idx < HR_CALC_BUFFER_SIZE) {
            hr_ir_sample_buffer[hr_buffer_idx] = max30100_ir_buffer[i];
            hr_red_sample_buffer[hr_buffer_idx] = max30100_red_buffer[i];
            hr_buffer_idx++;
        }
    }

    if (hr_buffer_idx >= HR_CALC_BUFFER_SIZE) {
        hr_buffer_full = 1;
        hr_buffer_idx = 0;
    }

    if (hr_buffer_full) {
        float dc_ir = calculateDC(hr_ir_sample_buffer, HR_CALC_BUFFER_SIZE);
        float dc_red = calculateDC(hr_red_sample_buffer, HR_CALC_BUFFER_SIZE);
        float ac_ir = calculateAC(hr_ir_sample_buffer, HR_CALC_BUFFER_SIZE);
        float ac_red = calculateAC(hr_red_sample_buffer, HR_CALC_BUFFER_SIZE);

        float spo2 = 0.0f;
        float ratio = 0.0f;

        if (dc_ir > 1000 && dc_red > 1000 && ac_ir > 20 && ac_red > 20) {
            ratio = (ac_red / dc_red) / (ac_ir / dc_ir);
            // Using a more standard quadratic formula. You might need to adjust/calibrate.
            // spo2 = -45.060f * ratio * ratio + 30.354f * ratio + 94.845f;
            // Or your original linear:
            spo2 = -45.060f * ratio + 110.4f;

            if (spo2 > 100.0f) spo2 = 100.0f;
            if (spo2 < 70.0f) spo2 = 70.0f;
        } else {
            spo2 = 0.0f;
        }

        float heartRate = 0.0f;
        float peak_threshold = dc_ir + (ac_ir * 0.3f); // Adjust 0.3f (30%) as needed
        float min_peak_dist_samples = ppg_sample_rate_hz / (240.0f / 60.0f) ; // For max HR of 240bpm

        int peaks = countPeaks(hr_ir_sample_buffer, HR_CALC_BUFFER_SIZE, peak_threshold, min_peak_dist_samples);

        if (peaks > 0) {
            float window_duration_sec = (float)HR_CALC_BUFFER_SIZE / ppg_sample_rate_hz;
            heartRate = (float)peaks * 60.0f / window_duration_sec;
        }
        // Sanity checks for HR
        if (heartRate > 220.0f || (heartRate < 40.0f && heartRate != 0.0f)) {
             // heartRate = 0.0f; // Or print as is for debugging
        }


        char data_buf[120]; // Increased buffer size
        sprintf(data_buf, "HR:%.1fbpm SpO2:%.1f%% IR(DC:%.0f AC:%.0f) RED(DC:%.0f AC:%.0f) R:%.3f Pks:%d\r\n",
                heartRate, spo2, dc_ir, ac_ir, dc_red, ac_red, ratio, peaks);
        secure_uart_send((uint8_t*)data_buf, strlen(data_buf));

        hr_buffer_full = 0;
        hr_buffer_idx = 0;
    }
}

float calculateDC(uint16_t *samples, uint16_t size) {
    if (size == 0) return 0.0f;
    uint32_t sum = 0;
    for (uint16_t i = 0; i < size; i++) {
        sum += samples[i];
    }
    return (float)sum / size;
}

float calculateAC(uint16_t *samples, uint16_t size) {
    if (size < 2) return 0.0f; // Need at least 2 samples for a difference
    uint16_t max_val = samples[0];
    uint16_t min_val = samples[0];
    for (uint16_t i = 1; i < size; i++) {
        if (samples[i] > max_val) max_val = samples[i];
        if (samples[i] < min_val) min_val = samples[i];
    }
    return (float)(max_val - min_val);
}

int countPeaks(uint16_t *samples, uint16_t size, float threshold, float min_peak_distance_samples) {
    int peak_count = 0;
    uint16_t last_peak_idx = 0; // Initialize to 0 or a value that ensures first peak can be detected

    if (size < 3) return 0;

    for (uint16_t i = 1; i < size - 1; i++) {
        // Basic peak: higher than neighbors and above threshold
        if (samples[i] > threshold && samples[i] > samples[i-1] && samples[i] >= samples[i+1]) {
            // Check minimum distance from the previously detected peak
            if (last_peak_idx == 0 || (i - last_peak_idx) >= min_peak_distance_samples) {
                 peak_count++;
                 last_peak_idx = i;
            }
        }
    }
    return peak_count;
}

// Reads temperature from LM35 sensor connected to PA3 (ADC1_INP15)
void readLM35Temperature(void) {
    uint32_t adc_sum = 0;
    const int num_samples = 32; // Number of samples to average

    // Ensure ADC is started and poll for conversion
    // This assumes hadc1 is already configured for PA3 (ADC1_INP15) in MX_ADC1_Init()
    if (HAL_ADC_Start(&hadc1) != HAL_OK) {
        printf("Error: HAL_ADC_Start failed for LM35.\r\n");
        return;
    }

    for (int i = 0; i < num_samples; i++) {
        if (HAL_ADC_PollForConversion(&hadc1, 100) == HAL_OK) { // 100ms timeout per conversion
            adc_sum += HAL_ADC_GetValue(&hadc1);
        } else {
            printf("Warning: ADC Poll for LM35 timed out on sample %d.\r\n", i + 1);
            // Optionally break or continue with fewer samples
        }
    }
    HAL_ADC_Stop(&hadc1);

    if (num_samples == 0) return; // Should not happen with const > 0
    uint32_t raw_adc = adc_sum / num_samples;

    // VREF typically 3.3V. STM32H7 ADC can be 16-bit (65535) or 12-bit (4095) etc.
    // Check your CubeMX ADC resolution setting. Default for many H7 is 16-bit.
    // If ADC resolution is 12-bit, use 4095.0f. If 16-bit, use 65535.0f.
    float adc_resolution_divider = 65535.0f; // Assuming 16-bit resolution
    // float adc_resolution_divider = 4095.0f; // If using 12-bit resolution

    float voltage = (raw_adc * 3.3f) / adc_resolution_divider;
    float tempC = voltage * 100.0f;  // LM35: 10mV/°C -> V / 0.01 = V * 100

    char buf[50]; // Increased buffer size
    sprintf(buf, "LM35 Temp: %.1f C (ADC Raw Avg: %lu)\r\n", tempC, raw_adc);
    secure_uart_send((uint8_t*)buf, strlen(buf));
}

/**
  * @brief ADC1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_ADC1_Init(void)
{

  /* USER CODE BEGIN ADC1_Init 0 */

  /* USER CODE END ADC1_Init 0 */

  ADC_MultiModeTypeDef multimode = {0};
  ADC_ChannelConfTypeDef sConfig = {0};

  /* USER CODE BEGIN ADC1_Init 1 */

  /* USER CODE END ADC1_Init 1 */

  /** Common config
  */
  hadc1.Instance = ADC1;
  hadc1.Init.ClockPrescaler = ADC_CLOCK_ASYNC_DIV1;
  hadc1.Init.Resolution = ADC_RESOLUTION_16B;
  hadc1.Init.ScanConvMode = ADC_SCAN_DISABLE;
  hadc1.Init.EOCSelection = ADC_EOC_SINGLE_CONV;
  hadc1.Init.LowPowerAutoWait = DISABLE;
  hadc1.Init.ContinuousConvMode = DISABLE;
  hadc1.Init.NbrOfConversion = 1;
  hadc1.Init.DiscontinuousConvMode = DISABLE;
  hadc1.Init.ExternalTrigConv = ADC_SOFTWARE_START;
  hadc1.Init.ExternalTrigConvEdge = ADC_EXTERNALTRIGCONVEDGE_NONE;
  hadc1.Init.ConversionDataManagement = ADC_CONVERSIONDATA_DR;
  hadc1.Init.Overrun = ADC_OVR_DATA_PRESERVED;
  hadc1.Init.LeftBitShift = ADC_LEFTBITSHIFT_NONE;
  hadc1.Init.OversamplingMode = DISABLE;
  hadc1.Init.Oversampling.Ratio = 1;
  if (HAL_ADC_Init(&hadc1) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure the ADC multi-mode
  */
  multimode.Mode = ADC_MODE_INDEPENDENT;
  if (HAL_ADCEx_MultiModeConfigChannel(&hadc1, &multimode) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure Regular Channel
  */
  sConfig.Channel = ADC_CHANNEL_10;
  sConfig.Rank = ADC_REGULAR_RANK_1;
  sConfig.SamplingTime = ADC_SAMPLETIME_1CYCLE_5;
  sConfig.SingleDiff = ADC_SINGLE_ENDED;
  sConfig.OffsetNumber = ADC_OFFSET_NONE;
  sConfig.Offset = 0;
  sConfig.OffsetSignedSaturation = DISABLE;
  if (HAL_ADC_ConfigChannel(&hadc1, &sConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN ADC1_Init 2 */

  /* USER CODE END ADC1_Init 2 */

}

/**
  * @brief I2C1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_I2C1_Init(void)
{

  /* USER CODE BEGIN I2C1_Init 0 */

  /* USER CODE END I2C1_Init 0 */

  /* USER CODE BEGIN I2C1_Init 1 */

  /* USER CODE END I2C1_Init 1 */
  hi2c1.Instance = I2C1;
  hi2c1.Init.Timing = 0x00B03FDB;
  hi2c1.Init.OwnAddress1 = 0;
  hi2c1.Init.AddressingMode = I2C_ADDRESSINGMODE_7BIT;
  hi2c1.Init.DualAddressMode = I2C_DUALADDRESS_DISABLE;
  hi2c1.Init.OwnAddress2 = 0;
  hi2c1.Init.OwnAddress2Masks = I2C_OA2_NOMASK;
  hi2c1.Init.GeneralCallMode = I2C_GENERALCALL_DISABLE;
  hi2c1.Init.NoStretchMode = I2C_NOSTRETCH_DISABLE;
  if (HAL_I2C_Init(&hi2c1) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure Analogue filter
  */
  if (HAL_I2CEx_ConfigAnalogFilter(&hi2c1, I2C_ANALOGFILTER_ENABLE) != HAL_OK)
  {
    Error_Handler();
  }

  /** Configure Digital filter
  */
  if (HAL_I2CEx_ConfigDigitalFilter(&hi2c1, 0) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN I2C1_Init 2 */

  /* USER CODE END I2C1_Init 2 */

}

/**
  * @brief TIM6 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM6_Init(void)
{

  /* USER CODE BEGIN TIM6_Init 0 */

  /* USER CODE END TIM6_Init 0 */

  TIM_MasterConfigTypeDef sMasterConfig = {0};

  /* USER CODE BEGIN TIM6_Init 1 */

  /* USER CODE END TIM6_Init 1 */
  htim6.Instance = TIM6;
  htim6.Init.Prescaler = 0;
  htim6.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim6.Init.Period = 65535;
  htim6.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  if (HAL_TIM_Base_Init(&htim6) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim6, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM6_Init 2 */

  /* USER CODE END TIM6_Init 2 */

}

/**
  * @brief USART3 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART3_UART_Init(void)
{

  /* USER CODE BEGIN USART3_Init 0 */

  /* USER CODE END USART3_Init 0 */

  /* USER CODE BEGIN USART3_Init 1 */

  /* USER CODE END USART3_Init 1 */
  huart3.Instance = USART3;
  huart3.Init.BaudRate = 115200;
  huart3.Init.WordLength = UART_WORDLENGTH_8B;
  huart3.Init.StopBits = UART_STOPBITS_1;
  huart3.Init.Parity = UART_PARITY_NONE;
  huart3.Init.Mode = UART_MODE_TX_RX;
  huart3.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart3.Init.OverSampling = UART_OVERSAMPLING_16;
  huart3.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  huart3.Init.ClockPrescaler = UART_PRESCALER_DIV1;
  huart3.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  if (HAL_UART_Init(&huart3) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_SetTxFifoThreshold(&huart3, UART_TXFIFO_THRESHOLD_1_8) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_SetRxFifoThreshold(&huart3, UART_RXFIFO_THRESHOLD_1_8) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_UARTEx_DisableFifoMode(&huart3) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART3_Init 2 */

  /* USER CODE END USART3_Init 2 */

}

/**
  * Enable DMA controller clock
  */
static void MX_DMA_Init(void)
{

  /* DMA controller clock enable */
  __HAL_RCC_DMA1_CLK_ENABLE();

  /* DMA interrupt init */
  /* DMA1_Stream0_IRQn interrupt configuration */
  HAL_NVIC_SetPriority(DMA1_Stream0_IRQn, 5, 0);
  HAL_NVIC_EnableIRQ(DMA1_Stream0_IRQn);

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOD_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();

  /* USER CODE BEGIN MX_GPIO_Init_2 */
  // Configure MAX30100 INT pin on PB5 as EXTI rising edge (adjust if wired differently)
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  GPIO_InitStruct.Pin = GPIO_PIN_5;
  GPIO_InitStruct.Mode = GPIO_MODE_IT_RISING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  // Enable EXTI line interrupt for PB5
  HAL_NVIC_SetPriority(EXTI9_5_IRQn, 5, 0);
  HAL_NVIC_EnableIRQ(EXTI9_5_IRQn);

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */
// ITM retarget using CMSIS definitions (avoid redefining ITM_Type)
#include <stdint.h>
#include <stdio.h>
#include "core_cm4.h"

static uint32_t ITM_SendChar0(uint32_t ch)
{
  if ((ITM->TCR & ITM_TCR_ITMENA_Msk) != 0UL) {
    if ((ITM->TER & 1UL) != 0UL) {
      /* Port 0 ready when u32 write does not stall; write via 8-bit alias */
      while (ITM->PORT[0].u8 == 0UL) { }
      ITM->PORT[0].u8 = (uint8_t)ch;
    }
  }
  return ch;
}

int _write(int file, char *ptr, int len)
{
  (void)file;
  for (int i = 0; i < len; i++) {
    ITM_SendChar0((uint32_t)*ptr++);
  }
  return len;
}

/* USER CODE END 4 */

/* USER CODE BEGIN Header_StartDefaultTask */
/**
  * @brief  Function implementing the defaultTask thread.
  * @param  argument: Not used
  * @retval None
  */
/* USER CODE END Header_StartDefaultTask */
void StartDefaultTask(void *argument)
{
  /* USER CODE BEGIN 5 */
  /* Infinite loop */
  for(;;)
  {
    osDelay(1);
  }
  /* USER CODE END 5 */
}

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}

#ifdef  USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
