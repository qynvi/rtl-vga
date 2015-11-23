library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

library lpm;
use lpm.lpm_components.all;

entity fgi is
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
			clk: in std_logic;
			r_switch,g_switch,b_switch: in std_logic;
			pixel_clk: buffer std_logic;
			Hsync,Vsync: buffer std_logic;
			R,G,B: out std_logic_vector(9 downto 0);
			nblank,nsync: out std_logic);
end fgi;

architecture vga of fgi is
	signal Hactive,Vactive,dena: std_logic;
	signal address: std_logic_vector(8 downto 0);
	signal intensity: std_logic_vector(9 downto 0);
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

	myrom: lpm_rom
		generic map (
			lpm_widthad => 9,
			lpm_outdata => "UNREGISTERED",
			lpm_address_control => "REGISTERED",
			---------------------------------------------------------
			lpm_file => "img.mif", -- data file containing image data
			---------------------------------------------------------
			lpm_width => 10)
		port map (
			inclock=>not pixel_clk, address=>address, q=>intensity);

	process (Vsync, Hsync)
		variable line_counter: integer range 0 to Vd;
	begin
		if (Vsync = '0') then
			line_counter := 0;
		elsif (Hsync'event and Hsync='1') then
			if (Vactive='1') then
				line_counter := line_counter + 1;
			end if;
		end if;
		address <= conv_std_logic_vector(line_counter, 9);
	end process;

	R<=intensity when r_switch='1' and dena='1' else (others=>'0');
	G<=intensity when g_switch='1' and dena='1' else (others=>'0');
	B<=intensity when b_switch='1' and dena='1' else (others=>'0');

end vga;
