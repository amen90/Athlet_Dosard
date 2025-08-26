/* An STM32 HAL library written for the MAX30100 pulse oximeter and heart rate sensor. */
/* Libraries by @eepj www.github.com/eepj - Modified based on analysis */
#ifndef MAX30100_FOR_STM32_HAL_H
#define MAX30100_FOR_STM32_HAL_H

#include "main.h" // Assuming this includes your STM32 HAL drivers
#include <string.h>
#include <stdio.h> // For printf in debug messages

/*----------------------------------------------------------------------------*/
// General Configuration
#define MAX30100_I2C_ADDR					0xAE // 7-bit address 0x57 shifted left by 1
#define MAX30100_I2C_TIMEOUT				100  // Reduced timeout for potentially faster recovery
#define MAX30100_DEFAULT_TIMEOUT            HAL_MAX_DELAY // For UART

// FIFO Configuration
#define MAX30100_FIFO_DEPTH					32   // MAX30100 has a 32-sample FIFO
#define MAX30100_SAMPLES_PER_READ			16   // Number of samples to read when A_FULL triggers (16 samples = 16 IR + 16 RED)
#define MAX30100_BYTES_PER_SAMPLE			4    // 2 bytes for IR, 2 bytes for RED
#define MAX30100_BUFFER_SIZE_BYTES			(MAX30100_SAMPLES_PER_READ * MAX30100_BYTES_PER_SAMPLE) // 16*4 = 64 bytes

/*----------------------------------------------------------------------------*/
// Register Addresses
// Status registers
#define MAX30100_INTERRUPT_STATUS			0x00
#define MAX30100_INTERRUPT_ENABLE			0x01
// FIFO registers
#define MAX30100_FIFO_WR_PTR				0x02
#define MAX30100_OVF_COUNTER				0x03
#define MAX30100_FIFO_RD_PTR				0x04
#define MAX30100_FIFO_DATA					0x05
// Config registers
#define MAX30100_MODE_CONFIG				0x06
#define MAX30100_SPO2_CONFIG				0x07
#define MAX30100_LED_CONFIG					0x09
// Temperature registers
#define MAX30100_TEMP_INTEGER				0x16
#define MAX30100_TEMP_FRACTION				0x17
// Part ID registers
#define MAX30100_REVISION_ID				0xFE
#define MAX30100_PART_ID					0xFF // Should read 0x11

/*----------------------------------------------------------------------------*/
// Register Bit Masks
// INTERRUPT_STATUS and INTERRUPT_ENABLE
#define MAX30100_INT_A_FULL_MASK			(1 << 7)
#define MAX30100_INT_TEMP_RDY_MASK			(1 << 6)
#define MAX30100_INT_HR_RDY_MASK			(1 << 5) // Not typically used with FIFO
#define MAX30100_INT_SPO2_RDY_MASK			(1 << 4) // Not typically used with FIFO
#define MAX30100_INT_PWR_RDY_MASK           (1 << 0) // Power Ready Interrupt

// MODE_CONFIG
#define MAX30100_MODE_SHDN_MASK				(1 << 7)
#define MAX30100_MODE_RESET_MASK			(1 << 6)
#define MAX30100_MODE_TEMP_EN_MASK			(1 << 3)
#define MAX30100_MODE_MASK					0x07
#define MAX30100_MODE_HRONLY				0x02
#define MAX30100_MODE_SPO2_HR				0x03

// SPO2_CONFIG
#define MAX30100_SPO2_HI_RES_EN_MASK		(1 << 6) // Set for SpO2 mode
#define MAX30100_SPO2_SR_MASK				0x1C
#define MAX30100_SPO2_PW_MASK				0x03

// LED_CONFIG
#define MAX30100_LED_RED_PA_MASK			0xF0
#define MAX30100_LED_IR_PA_MASK				0x0F

/*----------------------------------------------------------------------------*/
// Global flag indicating new data is available from FIFO
// This flag is set in MAX30100_InterruptHandler and cleared in the main application loop.
extern volatile uint8_t max30100_new_data_available;

/*----------------------------------------------------------------------------*/
// Enumerations for configuration
typedef enum {
    MAX30100_SPO2_SAMPLERATE_50HZ = 0,  // 50 samples per second
    MAX30100_SPO2_SAMPLERATE_100HZ,     // 100 samples per second (DEFAULT)
    MAX30100_SPO2_SAMPLERATE_167HZ,     // 167 samples per second
    MAX30100_SPO2_SAMPLERATE_200HZ,     // 200 samples per second
    MAX30100_SPO2_SAMPLERATE_400HZ,     // 400 samples per second
    MAX30100_SPO2_SAMPLERATE_600HZ,     // 600 samples per second
    MAX30100_SPO2_SAMPLERATE_800HZ,     // 800 samples per second
    MAX30100_SPO2_SAMPLERATE_1000HZ,    // 1000 samples per second
	MAX30100_SPO2_SAMPLERATE_DEFAULT = MAX30100_SPO2_SAMPLERATE_100HZ
} MAX30100_SpO2SampleRate;

typedef enum {
    MAX30100_PULSEWIDTH_200US_13BIT = 0, // 200us, 13-bit ADC
    MAX30100_PULSEWIDTH_400US_14BIT,    // 400us, 14-bit ADC
    MAX30100_PULSEWIDTH_800US_15BIT,    // 800us, 15-bit ADC
    MAX30100_PULSEWIDTH_1600US_16BIT,   // 1600us, 16-bit ADC (DEFAULT)
	MAX30100_PULSEWIDTH_DEFAULT = MAX30100_PULSEWIDTH_1600US_16BIT
} MAX30100_LedPulseWidth;

typedef enum {
    MAX30100_LEDCURRENT_0MA = 0,    // 0mA
    MAX30100_LEDCURRENT_4_4MA,      // 4.4mA
    MAX30100_LEDCURRENT_7_6MA,      // 7.6mA
    MAX30100_LEDCURRENT_11_0MA,     // 11.0mA
    MAX30100_LEDCURRENT_14_2MA,     // 14.2mA
    MAX30100_LEDCURRENT_17_4MA,     // 17.4mA
    MAX30100_LEDCURRENT_20_8MA,     // 20.8mA
    MAX30100_LEDCURRENT_24_0MA,     // 24.0mA
    MAX30100_LEDCURRENT_27_1MA,     // 27.1mA
    MAX30100_LEDCURRENT_30_6MA,     // 30.6mA
    MAX30100_LEDCURRENT_33_8MA,     // 33.8mA
    MAX30100_LEDCURRENT_37_0MA,     // 37.0mA
    MAX30100_LEDCURRENT_40_2MA,     // 40.2mA
    MAX30100_LEDCURRENT_43_6MA,     // 43.6mA
    MAX30100_LEDCURRENT_46_8MA,     // 46.8mA
    MAX30100_LEDCURRENT_50_0MA,     // 50.0mA
	MAX30100_LEDCURRENT_DEFAULT = MAX30100_LEDCURRENT_20_8MA // A moderate default
} MAX30100_LedCurrent;

typedef enum {
    MAX30100_MODE_NONE   = 0x00,
    MAX30100_MODE_HRONLY_EN = MAX30100_MODE_HRONLY,
    MAX30100_MODE_SPO2_EN = MAX30100_MODE_SPO2_HR,
} MAX30100_OperatingMode;

/*----------------------------------------------------------------------------*/
// Public Function Prototypes

/**
 * @brief Initializes the MAX30100 sensor.
 * @param hi2c Pointer to I2C_HandleTypeDef structure.
 * @retval HAL_OK if initialization is successful, HAL_ERROR otherwise.
 */
HAL_StatusTypeDef MAX30100_Init(I2C_HandleTypeDef *hi2c);

/**
 * @brief Reads a register from MAX30100.
 * @param regAddr Register address.
 * @param pData Pointer to store the read byte.
 * @retval HAL_OK if successful, HAL_ERROR otherwise.
 */
HAL_StatusTypeDef MAX30100_ReadReg(uint8_t regAddr, uint8_t *pData);

/**
 * @brief Writes a byte to a MAX30100 register.
 * @param regAddr Register address.
 * @param data Byte to write.
 * @retval HAL_OK if successful, HAL_ERROR otherwise.
 */
HAL_StatusTypeDef MAX30100_WriteReg(uint8_t regAddr, uint8_t data);

/**
 * @brief Configures and enables specific interrupts.
 * @param enable_a_full Enable FIFO Almost Full interrupt.
 * @param enable_temp_rdy Enable Temperature Ready interrupt.
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_ConfigInterrupts(uint8_t enable_a_full, uint8_t enable_temp_rdy);

/**
 * @brief Interrupt handler to be called from STM32 EXTI ISR.
 * Reads interrupt status, processes FIFO or temperature data.
 */
void MAX30100_InterruptHandler(void);

/**
 * @brief Sets the operating mode (HR only or SpO2/HR).
 * @param mode Operating mode.
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_SetMode(MAX30100_OperatingMode mode);

/**
 * @brief Sets the SpO2 ADC sample rate.
 * @param sr Sample rate enum.
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_SetSpO2SampleRate(MAX30100_SpO2SampleRate sr);

/**
 * @brief Sets the LED pulse width (and implicitly ADC resolution).
 * @param pw Pulse width enum.
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_SetLedPulseWidth(MAX30100_LedPulseWidth pw);

/**
 * @brief Sets the current for Red and IR LEDs.
 * @param redCurrent Current for Red LED.
 * @param irCurrent Current for IR LED.
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_SetLedCurrents(MAX30100_LedCurrent redCurrent, MAX30100_LedCurrent irCurrent);

/**
 * @brief Clears FIFO read/write pointers and overflow counter.
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_ClearFIFO(void);

/**
 * @brief Reads data from FIFO into global buffers.
 * This function is typically called from MAX30100_InterruptHandler.
 * @param ir_data Pointer to array to store IR samples.
 * @param red_data Pointer to array to store Red samples.
 * @param num_samples Number of samples to read (should be MAX30100_SAMPLES_PER_READ).
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_ReadFifoData(uint16_t* ir_data, uint16_t* red_data, uint8_t num_samples);

/**
 * @brief Initiates a temperature reading and returns the value.
 * This is a blocking function.
 * @param pTemperature Pointer to store the temperature value.
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_ReadTemperature(float *pTemperature);

/**
 * @brief Puts the MAX30100 into shutdown mode.
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_Shutdown(void);

/**
 * @brief Wakes up the MAX30100 from shutdown mode.
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_WakeUp(void);

/**
 * @brief Performs a software reset of the MAX30100.
 * @retval HAL_OK if successful.
 */
HAL_StatusTypeDef MAX30100_Reset(void);

// Data buffers - accessible after MAX30100_ReadFifoData via MAX30100_InterruptHandler
// Consider making these part of a device handle struct for better encapsulation if using multiple sensors
// or for a cleaner global namespace. For simplicity, using the original approach.
extern uint16_t max30100_ir_buffer[MAX30100_SAMPLES_PER_READ];
extern uint16_t max30100_red_buffer[MAX30100_SAMPLES_PER_READ];
extern float max30100_last_temperature;

#endif /* MAX30100_FOR_STM32_HAL_H */
