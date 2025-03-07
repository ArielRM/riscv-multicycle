library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.decoder_types.all;

entity testbench is
    generic(
        --! Num of 32-bits memory words
        IMEMORY_WORDS : integer := 1024; --!= 4K (1024 * 4) bytes
        DMEMORY_WORDS : integer := 1024 --!= 2k (512 * 2) bytes
    );
end entity testbench;

architecture RTL of testbench is
    -- Clocks and reset
    signal clk     : std_logic;
    signal clk_32x : std_logic;
    signal rst     : std_logic;

    -- Instruction bus and instruction memory
    signal address  : std_logic_vector(9 downto 0);
    signal iaddress : unsigned(15 downto 0);
    signal idata    : std_logic_vector(31 downto 0);

    -- Data bus
    signal daddress    : unsigned(31 downto 0);
    signal ddata_r     : std_logic_vector(31 downto 0);
    signal ddata_w     : std_logic_vector(31 downto 0);
    signal dmask       : std_logic_vector(3 downto 0);
    signal dcsel       : std_logic_vector(1 downto 0);
    signal d_we        : std_logic := '0';
    signal ddata_r_mem : std_logic_vector(31 downto 0);
    signal d_rd        : std_logic;
    signal d_sig       : std_logic;

    -- Modelsim debug signals
    signal cpu_state   : cpu_state_t;
    signal debugString : string(1 to 40) := (others => '0');

    -- I/O signals
    signal interrupts   : std_logic_vector(31 downto 0);
    signal ddata_r_gpio : std_logic_vector(31 downto 0);
    signal gpio_input   : std_logic_vector(31 downto 0);
    signal gpio_output  : std_logic_vector(31 downto 0);

    signal ddata_r_timer   : std_logic_vector(31 downto 0);
    signal timer_interrupt : std_logic_vector(5 downto 0);
    signal ddata_r_periph  : std_logic_vector(31 downto 0);
    signal ddata_r_sdram   : std_logic_vector(31 downto 0);

    signal gpio_interrupts  : std_logic_vector(6 downto 0);
    signal ddata_r_segments : std_logic_vector(31 downto 0);
    signal ddata_r_uart     : std_logic_vector(31 downto 0);
    signal ddata_r_adc      : std_logic_vector(31 downto 0);
    signal ddata_r_i2c      : std_logic_vector(31 downto 0);

    signal uart_interrupts : std_logic_vector(1 downto 0);
    signal ifcap           : std_logic;
    signal ddata_r_dif_fil : std_logic_vector(31 downto 0);
    signal ddata_r_stepmot : std_logic_vector(31 downto 0);
    signal ddata_r_lcd : std_logic_vector(31 downto 0);
    signal ddata_r_nn_accelerator : std_logic_vector(31 downto 0);
    signal ddata_r_fir_fil : std_logic_vector(31 downto 0);

begin

    clock_driver : process
        constant period : time := 1000 ns;
    begin
        clk <= '0';
        wait for period / 2;
        clk <= '1';
        wait for period / 2;
    end process clock_driver;

    --! Division unit clock
    clock_driver_32x : process
        constant period : time := 20 ns;
    begin
        clk_32x <= '0';
        wait for period / 2;
        clk_32x <= '1';
        wait for period / 2;
    end process clock_driver_32x;

    reset : process is
    begin
        rst <= '1';
        wait for 150 ns;
        rst <= '0';
        wait;
    end process reset;

    -- IMem shoud be read from instruction and data buses
    -- Not enough RAM ports for instruction bus, data bus and in-circuit programming
    instr_mux : entity work.instructionbusmux
        port map(
            d_rd     => d_rd,
            dcsel    => dcsel,
            daddress => daddress,
            iaddress => iaddress,
            address  => address
        );

    -- 32-bits x 1024 words quartus RAM (dual port: portA -> riscV, portB -> In-System Mem Editor
    iram_quartus_inst : entity work.iram_quartus
        port map(
            address => address(9 downto 0),
            byteena => "1111",
            clock   => clk,
            data    => (others => '0'),
            wren    => '0',
            q       => idata
        );

    -- dmemory_address <= daddress;
    -- Data Memory RAM
    dmem : entity work.dmemory
        generic map(
            MEMORY_WORDS => DMEMORY_WORDS
        )
        port map(
            rst        => rst,
            clk        => clk,
            data       => ddata_w,
            address    => daddress,
            we         => d_we,
            signal_ext => d_sig,
            csel       => dcsel(0),
            dmask      => dmask,
            q          => ddata_r_mem
        );

    -- Adress space mux ((check sections.ld) -> Data chip select:
    -- 0x00000    ->    Instruction memory
    -- 0x20000    ->    Data memory
    -- 0x40000    ->    Input/Output generic address space
    -- 0x60000    ->    SDRAM address space
    data_bus_mux : entity work.databusmux
        port map(
            dcsel          => dcsel,
            idata          => idata,
            ddata_r_mem    => ddata_r_mem,
            ddata_r_periph => ddata_r_periph,
            ddata_r_sdram  => ddata_r_sdram,
            ddata_r        => ddata_r
        );

    io_data_bus_mux : entity work.iodatabusmux
        port map(
            daddress         => daddress,
            ddata_r_gpio     => ddata_r_gpio,
            ddata_r_segments => ddata_r_segments,
            ddata_r_uart     => ddata_r_uart,
            ddata_r_adc      => ddata_r_adc,
            ddata_r_i2c      => ddata_r_i2c,
            ddata_r_timer    => ddata_r_timer,
            ddata_r_dif_fil => ddata_r_dif_fil,
            ddata_r_stepmot => ddata_r_stepmot,
            ddata_r_lcd => ddata_r_lcd,
            ddata_r_nn_accelerator => ddata_r_nn_accelerator,
            ddata_r_fir_fil => ddata_r_fir_fil,
            ddata_r_periph   => ddata_r_periph
        );

    -- Softcore instatiation
    myRiscv : entity work.core
        port map(
            clk        => clk,
            rst        => rst,
            clk_32x    => clk_32x,
            iaddress   => iaddress,
            idata      => idata,
            daddress   => daddress,
            ddata_r    => ddata_r,
            ddata_w    => ddata_w,
            d_we       => d_we,
            d_rd       => d_rd,
            d_sig      => d_sig,
            dcsel      => dcsel,
            dmask      => dmask,
            interrupts => interrupts,
            state      => cpu_state
        );

    -- Group IRQ signals.
    irq_signals : process(timer_interrupt, gpio_interrupts, uart_interrupts)
    begin
        interrupts               <= (others => '0');
        interrupts(24 downto 18) <= gpio_interrupts(6 downto 0);
        interrupts(30 downto 25) <= timer_interrupt;
        interrupts(31)           <= uart_interrupts(0);
    end process;

    -- Generic GPIO module instantiation
    generic_gpio : entity work.gpio
        port map(
            clk             => clk,
            rst             => rst,
            daddress        => daddress,
            ddata_w         => ddata_w,
            ddata_r         => ddata_r_gpio,
            d_we            => d_we,
            d_rd            => d_rd,
            dcsel           => dcsel,
            dmask           => dmask,
            input           => gpio_input,
            output          => gpio_output,
            gpio_interrupts => gpio_interrupts
        );

    -- timer instantiation
    timer : entity work.Timer
        generic map(
            prescaler_size => 16,
            compare_size   => 32
        )
        port map(
            clock           => clk,
            reset           => rst,
            daddress        => daddress,
            ddata_w         => ddata_w,
            ddata_r         => ddata_r_gpio,
            d_we            => d_we,
            d_rd            => d_rd,
            dcsel           => dcsel,
            dmask           => dmask,
            timer_interrupt => timer_interrupt,
            ifcap           => ifcap
        );

    -- FileOutput DEBUG 
    debug : entity work.trace_debug
        generic map(
            MEMORY_WORDS => IMEMORY_WORDS
        )
        port map(
            pc   => iaddress,
            data => idata,
            inst => debugString
        );

    process is
        constant period : time := 1000 ns;
    begin
        ifcap <= '0';
        wait for 10 * period;

        ifcap <= '1';
        wait for period;

    end process;

end architecture RTL;
