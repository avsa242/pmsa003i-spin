{
----------------------------------------------------------------------------------------------------
    Filename:       sensor.particle.pmsa003i.spin
    Description:    Driver for the PLANTOWER PMSA0031 particle concentration sensor
    Author:         Jesse Burt
    Started:        Aug 28, 2022
    Updated:        Oct 2, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    { default I/O settings; these can be overridden in the parent object }
    SCL         = 28
    SDA         = 29
    I2C_FREQ    = 100_000                       ' max: 100_000
    I2C_ADDR    = 0


    SLAVE_WR    = core.SLAVE_ADDR
    SLAVE_RD    = core.SLAVE_ADDR|1
    I2C_MAX_FREQ= core.I2C_MAX_FREQ


VAR

    byte _reg[32]


OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef PMSA0031_I2C_BC
    i2c:    "com.i2c.nocog"                     ' BC I2C engine
#else
    i2c:    "com.i2c"                           ' PASM I2C engine
#endif
    core:   "core.con.pmsa003i"                 ' HW-specific constants
    time:   "time"                              ' timekeeping methods


PUB null()
' This is not a top-level object


PUB start(): status
' Start using default I/O settings
    return startx(SCL, SDA, I2C_FREQ)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start the driver with custom I/O settings
'   SCL_PIN:    I2C clock, 0..31
'   SDA_PIN:    I2C data, 0..31
'   I2C_HZ:     I2C clock speed (max official specification is 100_000 but is unenforced)
'   Returns:
'       cog ID+1 of I2C engine on success (= calling cog ID+1, if the bytecode I2C engine is used)
'       0 on failure
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.usleep(core.T_POR)             ' wait for device startup
            if ( present() )                    ' test device bus presence
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()
    bytefill(@_reg, 0, 32)


PUB defaults()
' Set factory defaults


PUB present(): flag
' Flag indicating device is present
    i2c.start()
    flag := (i2c.write(SLAVE_WR) == i2c.ACK)
    i2c.stop()


PUB measure(): status | sum, reg_nr
' Perform a measurement
'   Returns:
'       0 if measurement data checksum verification passes
'       -1 if measurement data checksum verification fails
'   NOTE: Provide at least 30sec after powerup for stable data
'   NOTE: If checksum verification fails, the data will be zeroed
    i2c.start()
    i2c.write(SLAVE_RD)
    status := sum := 0
    repeat reg_nr from $00 to $1f
        _reg[reg_nr] := i2c.read(reg_nr == $1f) ' NAK if last reg
        if (reg_nr < core.CKSUM_MSB)
            sum += _reg[reg_nr]                 ' perform checksum
    i2c.stop()

    { compare calculated checksum to that received from the sensor }
    ifnot ( sum == (_reg[core.CKSUM_MSB] << 8 | _reg[core.CKSUM_LSB]) )
        status := -1                            ' checksum verification failed
        bytefill(@_reg, 0, 32)                  ' zero out data


PUB pm1_0(): p
' Particulate matter concentration (1.0um and smaller)
'   Returns: micro-grams per cubic meter
    return (_reg[core.PM1_0_STD_MSB] << 8) | _reg[core.PM1_0_STD_LSB]


PUB pm2_5(): p
' Particulate matter concentration (2.5um and smaller)
'   Returns: micro-grams per cubic meter
    return (_reg[core.PM2_5_STD_MSB] << 8) | _reg[core.PM2_5_STD_LSB]


PUB pm10(): p
' Particulate matter concentration (10um and smaller)
'   Returns: micro-grams per cubic meter
    return (_reg[core.PM10_STD_MSB] << 8) | _reg[core.PM10_STD_LSB]


PUB version(): ver
' Sensor version
'   NOTE: measure() must be called at least once prior to calling this method
    return _reg[core.VERSION]


DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

