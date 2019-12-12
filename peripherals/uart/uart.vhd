library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
	
	port(
		clk_in_1M	: in std_logic;
		clk_baud	: in std_logic;
		csel		: in std_logic;
		
		data_in		: in std_logic_vector(7 downto 0);
		tx 			: out std_logic;
		tx_cmp		: out std_logic;
		
		data_out	: out std_logic_vector(7 downto 0);
		rx			: in std_logic;
		rx_cmp		: out std_logic;
		
		config_all  : in std_logic_vector (31 downto 0)
	);
end entity uart;

architecture RTL of uart is		
	-- Signals for TX
	type state_tx_type is (IDLE, MOUNT_BYTE, TRANSMIT, MOUNT_BYTE_PARITY, TRANSMIT_PARITY);
	signal state_tx    :  state_tx_type := IDLE;
	signal cnt_tx	   :  integer       := 0;
	signal to_tx 	   :  std_logic_vector(10 downto 0) := (others => '1');
	signal to_tx_p 	   :  std_logic_vector(11 downto 0) := (others => '1');
	signal send_byte   : boolean        := FALSE;
	signal send_byte_p : boolean        := FALSE;
	
	-- Signals for RX
	type state_rx_type is (IDLE, READ_BYTE);
	signal state_rx      : state_rx_type := IDLE;
	signal cnt_rx	     : integer       := 0;
	signal byte_received : boolean       := FALSE;
	
	-- Signals for baud rates
	signal baud_19200 : std_logic := '0';
	signal baud_09600 : std_logic := '0';
	signal baud_04800 : std_logic := '0';
	signal baud_ready : std_logic := '0';
	
	-- Signals for parity
	signal parity : std_logic := '0';
	signal number : integer   := 0;
	
	------------ Function Count Ones -----------
	function count_ones(s : std_logic_vector) return integer is
  		variable temp : natural := 0;
	begin
  		for i in s'range loop
    		if s(i) = '1' then temp := temp + 1; 
    		end if;
  		end loop;
  		return temp;
	end function count_ones;
	
	----------- Function Parity Value ----------
	function parity_val(s : integer; setup : std_logic) return std_logic is
  		variable temp : std_logic := '0';
	begin	
		if    ((s mod 2) = 0) and (setup = '0') then --Paridade ativada impar
			temp := '0';
		elsif ((s mod 2) = 0) and (setup = '1') then --Paridade ativada par
			temp := '1';
		elsif ((s mod 2) = 1) and (setup = '0') then --Paridade ativada impar
			temp := '1';
		elsif ((s mod 2) = 1) and (setup = '1') then --Paridade ativada par
			temp := '0';
		end if;
		return temp;
	end function parity_val;
	
	
begin	--Baud Entrada = 38400

	------------- Baud Rate 19200 --------------
	baud19200: process(clk_baud, baud_19200) is
	begin	
		if rising_edge(clk_baud) and (baud_19200='0') then
			baud_19200 <= '1';
		elsif rising_edge(clk_baud) and (baud_19200='1') then
			baud_19200 <= '0';
		end if;
	end process;
	
	-------------- Baud Rate 9600 --------------
	baud9600: process(baud_19200, baud_09600) is
	begin	
		if rising_edge(baud_19200) and (baud_09600='0') then
			baud_09600 <= '1';
		elsif rising_edge(baud_19200) and (baud_09600='1') then
			baud_09600 <= '0';
		end if;
	end process;
	
	-------------- Baud Rate 4800 --------------
		baud4800: process(baud_09600, baud_04800) is
	begin	
		if rising_edge(baud_09600) and (baud_04800='0') then
			baud_04800 <= '1';
		elsif rising_edge(baud_09600) and (baud_04800='1') then
			baud_04800 <= '0';
		end if;
	end process;
	
	-------------- Baud Rate Select -------------
		baudselect: process(config_all(1 downto 0), baud_04800, baud_09600, baud_19200, clk_baud) is
	begin	
		case config_all(1 downto 0) is
			when "00" =>
				baud_ready <= clk_baud;
			when "01" =>
				baud_ready <= baud_19200;
			when "10" =>
				baud_ready <= baud_09600;
			when "11" =>
				baud_ready <= baud_04800;
			when others =>
				baud_ready <= baud_09600;
		end case;
	end process;
	
	---------------- Parity Setup ---------------
		parity_set: process(config_all(3 downto 2), number, data_in) is
	begin	
		if config_all(3) = '1' then
			number <= count_ones(data_in);
			parity <= parity_val(number, config_all(2));
		end if;	
	end process;
	
	-------------------- TX --------------------
	
	-- Maquina de estado TX: Moore
	estado_tx: process(clk_in_1M) is
	begin
		if rising_edge(clk_in_1M) then
			case state_tx is
				when IDLE =>
					if csel = '1' and config_all(3) = '1' then
						state_tx <= MOUNT_BYTE_PARITY;
					elsif csel = '1' and config_all(3) = '0' then
						state_tx <= MOUNT_BYTE;
					else
						state_tx <= IDLE;
					end if;
				when MOUNT_BYTE =>
					state_tx <= TRANSMIT;
				when MOUNT_BYTE_PARITY =>
					state_tx <= TRANSMIT_PARITY;
				when TRANSMIT =>
					if (cnt_tx < 10) then
						state_tx <= TRANSMIT;
					else
						state_tx <= IDLE;
					end if;
				when TRANSMIT_PARITY =>
					if (cnt_tx < 11) then
						state_tx <= TRANSMIT_PARITY;
					else
						state_tx <= IDLE;
					end if;
			end case;
		end if;
	end process;
	
	-- Maquina MEALY: transmission
	tx_proc: process(state_tx, data_in, parity)
	begin
		
		tx_cmp <= '0';
		send_byte <= FALSE;
		
		case state_tx is
			when IDLE =>
				tx_cmp 		<= '1';
				to_tx 		<= (others => '1');
				send_byte 	<= FALSE;
				
			when MOUNT_BYTE =>
				to_tx 		<= "11" & data_in & '0';
				tx_cmp 		<= '0';
				send_byte 	<= FALSE;
				
			when MOUNT_BYTE_PARITY =>
				to_tx_p 		<= "11" & data_in & parity & '0';
				tx_cmp 		<= '0';
				send_byte_p <= FALSE;
			
			when TRANSMIT =>
				send_byte 	<= TRUE;
				to_tx 		<= "11" & data_in & '0';
				
			when TRANSMIT_PARITY =>
				send_byte_p <= TRUE;
				to_tx_p 	<= "11" & data_in & parity & '0';
		end case;
		
	end process;
	
	tx_send: process(baud_ready)
	begin
		if rising_edge(baud_ready) then
			if send_byte = TRUE then
				tx 		<= to_tx(cnt_tx);
				cnt_tx 	<= cnt_tx + 1;
			elsif send_byte_p = TRUE then
				tx 		<= to_tx_p(cnt_tx);
				cnt_tx 	<= cnt_tx + 1;
			else
				tx 			<= '1';
				cnt_tx 		<= 0;
			end if;
		end if;
	end process;
	
	
	-------------------- RX --------------------
	-- Maquina de estado RX: Moore
	estado_rx: process(clk_in_1M) is
	begin
		if rising_edge(clk_in_1M) then
			case state_rx is
				when IDLE =>
					if rx = '0' then
						state_rx <= READ_BYTE;
					else
						state_rx <= IDLE;
					end if;
				when READ_BYTE =>
					if (cnt_rx < 10) then
						state_rx <= READ_BYTE;
					else
						state_rx <= IDLE;
					end if;
			end case;
		end if;
	end process;
	
	-- Maquina MEALY: transmission
	rx_proc: process(state_rx)
	begin
		
		case state_rx is
			when IDLE =>
				rx_cmp 		<= '1';
				byte_received <= FALSE;
				
			when READ_BYTE =>
				rx_cmp 		<= '0';
				byte_received 	<= TRUE;
			
		end case;
		
	end process;
	
	rx_receive: process(baud_ready, byte_received)
		variable from_rx 	: std_logic_vector(9 downto 0);
	begin
		if byte_received = TRUE then
			if rising_edge(baud_ready) then
				from_rx(cnt_rx)	:= rx;
				cnt_rx 	<= cnt_rx + 1;
				if cnt_rx = 8 then
					data_out <= from_rx(8 downto 1);
				end if;
			end if;
		else
			cnt_rx 	<= 0;
		end if;
	end process;
	
end architecture RTL;
