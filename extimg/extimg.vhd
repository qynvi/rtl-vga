library ieee;
use ieee.std_logic_1164.all;

entity extimg is
	generic(
			Ha: integer := 96; -- Hpulse
			Hb: integer := 144; -- Hpulse+HBP
			Hc: integer := 784; -- Hpulse+HBP+Hactive
			Hd: integer := 800; -- Hpulse+HBP+Hactive+HFP
			Va: integer := 2; -- Vpulse
			Vb: integer := 35; -- Vpulse+VBP
			Vc: integer := 515; -- Vpulse+VBP+Vactive
			Vd: integer := 525); -- Vpulse+VBP+Vactive+VFP
	port(
			clk: in std_logic; -- 50 MHz
			pixel_clk: buffer std_logic; -- 25 MHz
			Hsync,Vsync: buffer std_logic;
			R,G,B: out std_logic_vector(9 downto 0);
			nblank,nsync: out std_logic;
			nWE,nCE,nOE,nLB,nUB: out std_logic;
			address: out integer range 0 to 262143;
			data: in std_logic_vector(15 downto 0));
end extimg;

architecture ei of extimg is
	signal Hactive,Vactive,dena: std_logic;
	signal registered_data: std_logic_vector(15 downto 0);
	signal flag: std_logic;
begin

-- control generator
-----------------------------------------------------------------
	nblank <= '1';
	nsync <= '0';

	process (clk)
	begin
		if (clk'event and clk='1') then
			pixel_clk <= not pixel_clk;
		end if;
	end process;

	process (pixel_clk)
		variable Hcount: integer range 0 to Hd;
	begin
		if (pixel_clk'event and pixel_clk='1') then
			Hcount := Hcount + 1;
			if (Hcount=Ha) then
				Hsync <= '1';
			elsif (Hcount=Hb) then
				Hactive <= '1';
			elsif (Hcount=Hc) then
				Hactive <= '0';
			elsif (Hcount=Hd) then
				Hsync <= '0';
				Hcount := 0;
			end if;
		end if;
	end process;

	process (Hsync)
		variable Vcount: integer range 0 to Vd;
	begin
		if (Hsync'event and Hsync='0') then
			Vcount := Vcount + 1;
			if (Vcount=Va) then
				Vsync <= '1';
			elsif (Vcount=Vb) then
				Vactive <= '1';
			elsif (Vcount=Vc) then
				Vactive <= '0';
			elsif (Vcount=Vd) then
				Vsync <= '0';
				Vcount := 0;
			end if;
		end if;
	end process;

	dena <= (Hactive and Vactive);

---------------------------------------------------------------------------

-- image generator
---------------------------------------------------------------------------
	nWE <= '1';
	nCE <= '0';
	nOE <= '0';
	nLB <= '0';
	nUB <= '0';

	process (pixel_clk, Vsync)
		variable pixel_counter: integer range 0 to 262143;
	begin
		if (Vsync='0') then
			pixel_counter := 0;
			flag <= '0';
		elsif (pixel_clk'event and pixel_clk='1') then
			if (dena='1' and flag='1') then
				registered_data <= data;
				pixel_counter := pixel_counter + 1;
			end if;
			flag <= not flag;
		end if;
		address <= pixel_counter;
	end process;

	process (dena, flag, registered_data)
	begin
		if (dena='1') then
			if (flag='1') then
				R <= (registered_data(15 downto 8) & "00");
				G <= (registered_data(15 downto 8) & "00");
				B <= (registered_data(15 downto 8) & "00");
			else
				R <= (registered_data(7 downto 0) & "00");
				G <= (registered_data(7 downto 0) & "00");
				B <= (registered_data(7 downto 0) & "00");
			end if;
		else
			R <= (others => '0');
			G <= (others => '0');
			B <= (others => '0');
		end if;
	end process;

end ei;
