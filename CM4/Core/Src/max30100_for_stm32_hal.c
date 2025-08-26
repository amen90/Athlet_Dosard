/* An STM32 HAL library written for the MAX30100 pulse oximeter and heart rate sensor. */
/* Libraries by @eepj www.github.com/eepj - Modified based on analysis */

#include "max30100_for_stm32_hal.h"

// Global I2C Handle (initialized in MAX30100_Init)
static I2C_HandleTypeDef *_max30100_i2c_handle = NULL;

// Global data buffers
uint16_t max30100_ir_buffer[MAX30100_SAMPLES_PER_READ];
uint16_t max30100_red_buffer[MAX30100_SAMPLES_PER_READ];
float max30100_last_temperature = 0.0f;

// Global flag set by ISR, cleared by application
volatile uint8_t max30100_new_data_available = 0;

// Internal helper to read temperature registers
static HAL_StatusTypeDef MAX30100_ReadTemperatureRegisters(int8_t *temp_int, uint8_t *temp_frac) {
    if (MAX30100_ReadReg(MAX30100_TEMP_INTEGER, (uint8_t*)temp_int) != HAL_OK) return HAL_ERROR;
    if (MAX30100_ReadReg(MAX30100_TEMP_FRACTION, temp_frac) != HAL_OK) return HAL_ERROR;
    return HAL_OK;
}

HAL_StatusTypeDef MAX30100_ReadReg(uint8_t regAddr, uint8_t *pData) {
    if (_max30100_i2c_handle == NULL) return HAL_ERROR;
    HAL_StatusTypeDef status = HAL_I2C_Mem_Read(_max30100_i2c_handle, MAX30100_I2C_ADDR, regAddr, I2C_MEMADD_SIZE_8BIT, pData, 1, MAX30100_I2C_TIMEOUT);
    if (status != HAL_OK) {
        printf("MAX30100 I2C Read Error Reg:0x%02X, Status:%d\n", regAddr, status);
    }
    return status;
}

HAL_StatusTypeDef MAX30100_WriteReg(uint8_t regAddr, uint8_t data) {
    if (_max30100_i2c_handle == NULL) return HAL_ERROR;
    HAL_StatusTypeDef status = HAL_I2C_Mem_Write(_max30100_i2c_handle, MAX30100_I2C_ADDR, regAddr, I2C_MEMADD_SIZE_8BIT, &data, 1, MAX30100_I2C_TIMEOUT);
    if (status != HAL_OK) {
         printf("MAX30100 I2C Write Error Reg:0x%02X, Data:0x%02X, Status:%d\n", regAddr, data, status);
    }
    return status;
}

HAL_StatusTypeDef MAX30100_Reset(void) {
    uint8_t mode_cfg;
    if (MAX30100_ReadReg(MAX30100_MODE_CONFIG, &mode_cfg) != HAL_OK) return HAL_ERROR;
    if (MAX30100_WriteReg(MAX30100_MODE_CONFIG, mode_cfg | MAX30100_MODE_RESET_MASK) != HAL_OK) return HAL_ERROR;

    HAL_Delay(10); // Allow time for reset

    // Poll RESET bit to ensure it clears, or wait fixed time
    uint8_t retry = 0;
    do {
        if (MAX30100_ReadReg(MAX30100_MODE_CONFIG, &mode_cfg) != HAL_OK) return HAL_ERROR;
        if (!(mode_cfg & MAX30100_MODE_RESET_MASK)) break;
        HAL_Delay(10);
        retry++;
    } while (retry < 10);

    if (retry == 10) {
        printf("MAX30100 Reset bit did not clear.\n");
        return HAL_ERROR;
    }
    return HAL_OK;
}

HAL_StatusTypeDef MAX30100_Init(I2C_HandleTypeDef *hi2c) {
    _max30100_i2c_handle = hi2c;
    max30100_new_data_available = 0;

    if (MAX30100_Reset() != HAL_OK) {
        printf("MAX30100 Reset failed.\n");
        return HAL_ERROR;
    }

    // Verify Part ID
    uint8_t part_id;
    if (MAX30100_ReadReg(MAX30100_PART_ID, &part_id) != HAL_OK || part_id != 0x11) {
         printf("MAX30100 Part ID mismatch or read error. Expected 0x11, got 0x%02X\n", part_id);
        // return HAL_ERROR; // Continue for now, could be an issue with some modules/clones
    }


    // Default configurations
    if (MAX30100_WriteReg(MAX30100_INTERRUPT_ENABLE, 0x00) != HAL_OK) return HAL_ERROR; // Disable all interrupts initially
    if (MAX30100_ClearFIFO() != HAL_OK) return HAL_ERROR;
    if (MAX30100_SetLedPulseWidth(MAX30100_PULSEWIDTH_DEFAULT) != HAL_OK) return HAL_ERROR;
    if (MAX30100_SetSpO2SampleRate(MAX30100_SPO2_SAMPLERATE_DEFAULT) != HAL_OK) return HAL_ERROR;
    if (MAX30100_SetLedCurrents(MAX30100_LEDCURRENT_DEFAULT, MAX30100_LEDCURRENT_DEFAULT) != HAL_OK) return HAL_ERROR;

    // Configure SpO2 mode specific register settings
    uint8_t spo2_config_val;
    if(MAX30100_ReadReg(MAX30100_SPO2_CONFIG, &spo2_config_val) != HAL_OK) return HAL_ERROR;
    spo2_config_val |= MAX30100_SPO2_HI_RES_EN_MASK; // Enable HI-RES for SpO2 mode
    if(MAX30100_WriteReg(MAX30100_SPO2_CONFIG, spo2_config_val) != HAL_OK) return HAL_ERROR;

    // Enable A_FULL interrupt to start (temp can be enabled on demand)
    if (MAX30100_ConfigInterrupts(1, 0) != HAL_OK) return HAL_ERROR;

    return HAL_OK;
}

HAL_StatusTypeDef MAX30100_ConfigInterrupts(uint8_t enable_a_full, uint8_t enable_temp_rdy) {
    uint8_t int_enable_val = 0x00;
    if (enable_a_full) int_enable_val |= MAX30100_INT_A_FULL_MASK;
    if (enable_temp_rdy) int_enable_val |= MAX30100_INT_TEMP_RDY_MASK;
    return MAX30100_WriteReg(MAX30100_INTERRUPT_ENABLE, int_enable_val);
}

void MAX30100_InterruptHandler(void) {
    uint8_t int_status;
    if (MAX30100_ReadReg(MAX30100_INTERRUPT_STATUS, &int_status) != HAL_OK) {
        // Error reading interrupt status, cannot proceed
        return;
    }

    if (int_status & MAX30100_INT_A_FULL_MASK) {
        if (MAX30100_ReadFifoData(max30100_ir_buffer, max30100_red_buffer, MAX30100_SAMPLES_PER_READ) == HAL_OK) {
            max30100_new_data_available = 1;
        }
    }

    if (int_status & MAX30100_INT_TEMP_RDY_MASK) {
        int8_t temp_int;
        uint8_t temp_frac;
        if (MAX30100_ReadTemperatureRegisters(&temp_int, &temp_frac) == HAL_OK) {
            max30100_last_temperature = (float)temp_int + ((float)temp_frac * 0.0625f);
            // Optionally, set another flag like: max30100_new_temp_data_available = 1;
        }
        // Temp ready interrupt is usually one-shot; re-enable A_FULL if it was the primary one
        // Or simply ensure A_FULL interrupt enable wasn't cleared by temp reading logic.
        // The current design expects MAX30100_ReadTemperature to manage enabling/disabling temp int if needed.
        // If temp reading is always followed by A_FULL, ensure A_FULL_EN is still set.
        // For simplicity, we assume MAX30100_ConfigInterrupts is called correctly externally.
    }
}

HAL_StatusTypeDef MAX30100_SetMode(MAX30100_OperatingMode mode) {
    uint8_t mode_cfg_val;
    if (MAX30100_ReadReg(MAX30100_MODE_CONFIG, &mode_cfg_val) != HAL_OK) return HAL_ERROR;
    mode_cfg_val &= ~(MAX30100_MODE_MASK); // Clear mode bits
    mode_cfg_val |= (uint8_t)mode;
    return MAX30100_WriteReg(MAX30100_MODE_CONFIG, mode_cfg_val);
}

HAL_StatusTypeDef MAX30100_SetSpO2SampleRate(MAX30100_SpO2SampleRate sr) {
    uint8_t spo2_cfg_val;
    if (MAX30100_ReadReg(MAX30100_SPO2_CONFIG, &spo2_cfg_val) != HAL_OK) return HAL_ERROR;
    spo2_cfg_val &= ~(MAX30100_SPO2_SR_MASK); // Clear sample rate bits
    spo2_cfg_val |= ((uint8_t)sr << 2); // SR bits are [4:2]
    return MAX30100_WriteReg(MAX30100_SPO2_CONFIG, spo2_cfg_val);
}

HAL_StatusTypeDef MAX30100_SetLedPulseWidth(MAX30100_LedPulseWidth pw) {
    uint8_t spo2_cfg_val;
    if (MAX30100_ReadReg(MAX30100_SPO2_CONFIG, &spo2_cfg_val) != HAL_OK) return HAL_ERROR;
    spo2_cfg_val &= ~(MAX30100_SPO2_PW_MASK); // Clear pulse width bits
    spo2_cfg_val |= (uint8_t)pw; // PW bits are [1:0]
    return MAX30100_WriteReg(MAX30100_SPO2_CONFIG, spo2_cfg_val);
}

HAL_StatusTypeDef MAX30100_SetLedCurrents(MAX30100_LedCurrent redCurrent, MAX30100_LedCurrent irCurrent) {
    uint8_t led_cfg_val = (((uint8_t)redCurrent & 0x0F) << 4) | ((uint8_t)irCurrent & 0x0F);
    return MAX30100_WriteReg(MAX30100_LED_CONFIG, led_cfg_val);
}

HAL_StatusTypeDef MAX30100_ClearFIFO(void) {
    if (MAX30100_WriteReg(MAX30100_FIFO_WR_PTR, 0x00) != HAL_OK) return HAL_ERROR;
    if (MAX30100_WriteReg(MAX30100_FIFO_RD_PTR, 0x00) != HAL_OK) return HAL_ERROR;
    if (MAX30100_WriteReg(MAX30100_OVF_COUNTER, 0x00) != HAL_OK) return HAL_ERROR;
    return HAL_OK;
}

HAL_StatusTypeDef MAX30100_ReadFifoData(uint16_t* ir_data, uint16_t* red_data, uint8_t num_samples) {
    if (num_samples == 0 || num_samples > MAX30100_SAMPLES_PER_READ) return HAL_ERROR;

    uint8_t raw_fifo_data[MAX30100_BUFFER_SIZE_BYTES]; // Max 64 bytes for 16 samples
    uint16_t bytes_to_read = num_samples * MAX30100_BYTES_PER_SAMPLE;

    HAL_StatusTypeDef status = HAL_I2C_Mem_Read(_max30100_i2c_handle, MAX30100_I2C_ADDR, MAX30100_FIFO_DATA,
                                           I2C_MEMADD_SIZE_8BIT, raw_fifo_data, bytes_to_read, MAX30100_I2C_TIMEOUT);

    if (status == HAL_OK) {
        for (uint8_t i = 0; i < num_samples; i++) {
            uint16_t ir_sample_raw  = ((uint16_t)raw_fifo_data[i * MAX30100_BYTES_PER_SAMPLE + 0] << 8) | raw_fifo_data[i * MAX30100_BYTES_PER_SAMPLE + 1];
            uint16_t red_sample_raw = ((uint16_t)raw_fifo_data[i * MAX30100_BYTES_PER_SAMPLE + 2] << 8) | raw_fifo_data[i * MAX30100_BYTES_PER_SAMPLE + 3];

            // Depending on pulse width, samples might not use full 16 bits.
            // For 1600us pulse width (16-bit), this direct assignment is fine.
            // For shorter pulse widths, the MSBs might be zero.
            ir_data[i] = ir_sample_raw;
            red_data[i] = red_sample_raw;
        }
    } else {
         printf("MAX30100 FIFO Read Error: %d\n", status);
    }
    return status;
}

HAL_StatusTypeDef MAX30100_ReadTemperature(float *pTemperature) {
    uint8_t original_mode_cfg, current_int_enable;

    // Save current mode and interrupt config
    if (MAX30100_ReadReg(MAX30100_MODE_CONFIG, &original_mode_cfg) != HAL_OK) return HAL_ERROR;
    if (MAX30100_ReadReg(MAX30100_INTERRUPT_ENABLE, &current_int_enable) != HAL_OK) return HAL_ERROR;

    // Enable temperature measurement and Temp Ready Interrupt
    uint8_t temp_mode_cfg = (original_mode_cfg & ~MAX30100_MODE_SHDN_MASK & ~MAX30100_MODE_RESET_MASK); // Preserve current mode, ensure not shutdown/reset
    temp_mode_cfg |= MAX30100_MODE_TEMP_EN_MASK;
    if (MAX30100_WriteReg(MAX30100_MODE_CONFIG, temp_mode_cfg) != HAL_OK) return HAL_ERROR;
    if (MAX30100_ConfigInterrupts(0, 1) != HAL_OK) { // Disable A_FULL, Enable TEMP_RDY for this op
         MAX30100_WriteReg(MAX30100_MODE_CONFIG, original_mode_cfg); // Try to restore
        return HAL_ERROR;
    }

    // Wait for TEMP_RDY interrupt (or poll if not using ISR for this one-shot)
    // This example assumes ISR sets max30100_last_temperature or a specific flag
    // For a blocking call, you might poll the interrupt status register:
    uint8_t temp_int_status = 0;
    uint8_t retries = 50; // Approx 50 * 10ms = 500ms timeout
    while (retries--) {
        HAL_Delay(10); // Temp conversion is ~33ms
        if (MAX30100_ReadReg(MAX30100_INTERRUPT_STATUS, &temp_int_status) != HAL_OK) break; // I2C error
        if (temp_int_status & MAX30100_INT_TEMP_RDY_MASK) {
            int8_t temp_int_val;
            uint8_t temp_frac_val;
            if (MAX30100_ReadTemperatureRegisters(&temp_int_val, &temp_frac_val) == HAL_OK) {
                *pTemperature = (float)temp_int_val + ((float)temp_frac_val * 0.0625f);
                max30100_last_temperature = *pTemperature; // Update global too
            } else {
                temp_int_status = 0; // Mark as failed to read temp
                break;
            }
            break;
        }
    }

    // Restore original mode and interrupt configuration
    MAX30100_WriteReg(MAX30100_MODE_CONFIG, original_mode_cfg);
    MAX30100_WriteReg(MAX30100_INTERRUPT_ENABLE, current_int_enable);


    if (!(temp_int_status & MAX30100_INT_TEMP_RDY_MASK)) {
        printf("MAX30100 Temp Read Timeout or Error.\n");
        return HAL_TIMEOUT;
    }

    return HAL_OK;
}

HAL_StatusTypeDef MAX30100_Shutdown(void) {
    uint8_t mode_cfg_val;
    if (MAX30100_ReadReg(MAX30100_MODE_CONFIG, &mode_cfg_val) != HAL_OK) return HAL_ERROR;
    mode_cfg_val |= MAX30100_MODE_SHDN_MASK;
    return MAX30100_WriteReg(MAX30100_MODE_CONFIG, mode_cfg_val);
}

HAL_StatusTypeDef MAX30100_WakeUp(void) {
    uint8_t mode_cfg_val;
    if (MAX30100_ReadReg(MAX30100_MODE_CONFIG, &mode_cfg_val) != HAL_OK) return HAL_ERROR;
    mode_cfg_val &= ~MAX30100_MODE_SHDN_MASK;
    return MAX30100_WriteReg(MAX30100_MODE_CONFIG, mode_cfg_val);
}
