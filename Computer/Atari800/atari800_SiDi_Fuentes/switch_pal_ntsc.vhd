---------------------------------------------------------------------------
-- (c) 2019 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;
--USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

use ieee.std_logic_misc.all;

LIBRARY work;

ENTITY switch_pal_ntsc IS 
    GENERIC
    (
        CLOCKS : integer :=1;
        SYNC_ON : integer -- Which clock to send reset_n_out on and pll enable
    );
    PORT
    (
        RECONFIG_CLK : IN STD_LOGIC; -- A clock from another PLL
        RESET_N : IN STD_LOGIC;

        PAL : IN STD_LOGIC;

        INPUT_CLK : IN STD_LOGIC;
        PLL_CLKS : OUT STD_LOGIC_VECTOR(CLOCKS-1 downto 0);

        RESET_N_OUT : OUT STD_LOGIC
    );
END switch_pal_ntsc;

ARCHITECTURE vhdl OF switch_pal_ntsc IS 

    -- pal/ntsc switches
    signal pll_reconfig_areset : std_logic;
    signal pll_reconfig_configupdate : std_logic;
    signal pll_reconfig_scanclk : std_logic;
    signal pll_reconfig_scanclkena : std_logic;
    signal pll_reconfig_scandata : std_logic;
    signal pll_reconfig_scandataout : std_logic;
    signal pll_reconfig_scandone : std_logic;
    signal pll_reconfig_busy : std_logic;
    
    signal pll_reconfig_areset_pal : std_logic;
    signal pll_reconfig_configupdate_pal : std_logic;
    signal pll_reconfig_scanclk_pal : std_logic;
    signal pll_reconfig_scanclkena_pal : std_logic;
    signal pll_reconfig_scandata_pal : std_logic;
    signal pll_reconfig_scandataout_pal : std_logic;
    signal pll_reconfig_scandone_pal : std_logic;
    signal pll_reconfig_busy_pal : std_logic;

    signal pll_reconfig_areset_ntsc : std_logic;
    signal pll_reconfig_configupdate_ntsc : std_logic;
    signal pll_reconfig_scanclk_ntsc : std_logic;
    signal pll_reconfig_scanclkena_ntsc : std_logic;
    signal pll_reconfig_scandata_ntsc : std_logic;
    signal pll_reconfig_scandataout_ntsc : std_logic;
    signal pll_reconfig_scandone_ntsc : std_logic;
    signal pll_reconfig_busy_ntsc : std_logic;

    signal pll_pause_counter_reg : std_logic_vector(29 downto 0);
    signal pll_pause_counter_next : std_logic_vector(29 downto 0);    
    
    signal pll_enable_reg : std_logic;
    signal pll_enable_next : std_logic;
    signal pll_enable_reg_sync : std_logic;
    
    signal pll_state_reg : std_logic_vector(3 downto 0);
    signal pll_state_next : std_logic_vector(3 downto 0);
    constant PLL_STATE_WAIT : std_logic_vector(3 downto 0) := "0000";
    constant PLL_STATE_DISABLE : std_logic_vector(3 downto 0) := "0001";
    constant PLL_STATE_DISABLE_WAIT1 : std_logic_vector(3 downto 0) := "0010";
    constant PLL_STATE_DISABLE_WAIT2 : std_logic_vector(3 downto 0) := "0011";
    constant PLL_STATE_DISABLE_WAIT3 : std_logic_vector(3 downto 0) := "0100";
    constant PLL_STATE_DISABLE_WAIT4 : std_logic_vector(3 downto 0) := "0101";
    constant PLL_STATE_RECONFIG1 : std_logic_vector(3 downto 0) := "0110";
    constant PLL_STATE_RECONFIG1_WAIT_CONFIG : std_logic_vector(3 downto 0) := "0111";
    constant PLL_STATE_RECONFIG1_WAIT_LOCK : std_logic_vector(3 downto 0) := "1000";
    constant PLL_STATE_PAUSE1 : std_logic_vector(3 downto 0) := "1001";  
    
    signal pll_trigger_reconfig : std_logic;  
    signal pll_trigger_reconfig_downstream : std_logic;  
    
    signal pll_upstream_reset : std_logic;
    signal pll_upstream_reset_pal : std_logic;
    signal pll_upstream_reset_ntsc : std_logic;
    signal pll_downstream_reset : std_logic;
    
    signal reset_n_next : std_logic;
    signal reset_n_reg : std_logic;
    signal reset_n_reg_sync : std_logic;
    
	 signal CLK_PLL1 : std_logic;
	 signal PLL_LOCKED1 : std_logic;
	 signal PLL_LOCKED : std_logic;	 
	 
    signal CLK_RAW : std_logic_vector(5 downto 0);
  
    signal pal_fpga_sync : std_logic;
  
    signal reconfig_to_pal_reg : std_logic;
    signal reconfig_to_pal_next : std_logic;
    
BEGIN 

    generic_pll : entity work.pll_pal
    PORT MAP(inclk0 => INPUT_CLK,
             c0 => CLK_PLL1,
             locked => PLL_LOCKED1,
             areset => pll_reconfig_areset,
             -- from reconfig
             configupdate => pll_reconfig_configupdate,
             scanclk => pll_reconfig_scanclk,
             scanclkena => pll_reconfig_scanclkena,
             scandata => pll_reconfig_scandata,    
            -- back to reconfig 
             scandataout => pll_reconfig_scandataout,
             scandone => pll_reconfig_scandone         
             );
    generic_pll2 : entity work.pll_downstream_pal
    PORT MAP(inclk0 => CLK_PLL1,
             c0 => CLK_RAW(0),
             c1 => CLK_RAW(1),
             c2 => CLK_RAW(2),
             c3 => CLK_RAW(3),
             --c4 => CLK_RAW(4), 
             areset => pll_downstream_reset,
             locked => PLL_LOCKED
             );
     
     process(reconfig_to_pal_reg,
        pll_reconfig_scanclk_pal, pll_reconfig_scanclkena_pal, pll_reconfig_busy_pal, pll_reconfig_areset_pal,pll_reconfig_scandata_pal,pll_reconfig_configupdate_pal,
        pll_reconfig_scanclk_ntsc, pll_reconfig_scanclkena_ntsc, pll_reconfig_busy_ntsc, pll_reconfig_areset_ntsc,pll_reconfig_scandata_ntsc,pll_reconfig_configupdate_ntsc,
        pll_upstream_reset,pll_reconfig_scandone,pll_reconfig_scandataout
    )
     begin
        pll_upstream_reset_pal<= '0';
        pll_upstream_reset_ntsc <= '0';            
        pll_reconfig_scandone_pal <= '0';
        pll_reconfig_scandone_ntsc <= '0';
        pll_reconfig_scandataout_pal <= '0';
        pll_reconfig_scandataout_ntsc <= '0';
     
        if (reconfig_to_pal_reg='1') then
            pll_reconfig_scanclk<=pll_reconfig_scanclk_pal;
            pll_reconfig_scanclkena<=pll_reconfig_scanclkena_pal;
            pll_reconfig_scandata<= pll_reconfig_scandata_pal;
            pll_reconfig_busy <= pll_reconfig_busy_pal;
            pll_reconfig_areset <= pll_reconfig_areset_pal;                
            pll_reconfig_configupdate <= pll_reconfig_configupdate_pal;
                            
            pll_upstream_reset_pal <= pll_upstream_reset;
            pll_reconfig_scandone_pal <= pll_reconfig_scandone;
            pll_reconfig_scandataout_pal <= pll_reconfig_scandataout;                
        else
            pll_reconfig_scanclk<=pll_reconfig_scanclk_ntsc;
            pll_reconfig_scanclkena<=pll_reconfig_scanclkena_ntsc;
            pll_reconfig_scandata<= pll_reconfig_scandata_ntsc;
            pll_reconfig_busy <= pll_reconfig_busy_ntsc;
            pll_reconfig_areset <= pll_reconfig_areset_ntsc;        
            pll_reconfig_configupdate <= pll_reconfig_configupdate_ntsc;                
            
            pll_upstream_reset_ntsc <= pll_upstream_reset;
            pll_reconfig_scandone_ntsc  <= pll_reconfig_scandone;
            pll_reconfig_scandataout_ntsc <= pll_reconfig_scandataout;
        end if;
     end process;
             
     generic_pll1_reconfig : entity work.video_pll_reconfig
     PORT MAP
     ( 
         busy    => pll_reconfig_busy_ntsc,
         clock => RECONFIG_CLK,
         counter_param    => (OTHERS => '0'),
         counter_type    => (OTHERS => '0'),
         data_in    => (OTHERS => '0'),
         read_param    => '0',
         write_param => '0',
         --data_out    :    OUT  STD_LOGIC_VECTOR (8 DOWNTO 0);
         pll_areset    => pll_reconfig_areset_ntsc,
         pll_areset_in    => pll_upstream_reset_ntsc,
         pll_configupdate    => pll_reconfig_configupdate_ntsc,
         pll_scanclk => pll_reconfig_scanclk_ntsc,
         pll_scanclkena => pll_reconfig_scanclkena_ntsc,
         pll_scandata => pll_reconfig_scandata_ntsc,
         pll_scandataout => pll_reconfig_scandataout,
         pll_scandone    => pll_reconfig_scandone,
         
         reconfig => pll_trigger_reconfig,
         reset => not(RESET_N)
     );     

     generic_pll1_reconfig_pal : entity work.video_pll_reconfig_pal
     PORT MAP
     ( 
         busy    => pll_reconfig_busy_pal,
         clock => RECONFIG_CLK,
         counter_param    => (OTHERS => '0'),
         counter_type    => (OTHERS => '0'),
         data_in    => (OTHERS => '0'),
         read_param    => '0',
         write_param => '0',
         --data_out    :    OUT  STD_LOGIC_VECTOR (8 DOWNTO 0);
         pll_areset    => pll_reconfig_areset_pal,
         pll_areset_in    => pll_upstream_reset_pal,
         pll_configupdate    => pll_reconfig_configupdate_pal,
         pll_scanclk => pll_reconfig_scanclk_pal,
         pll_scanclkena => pll_reconfig_scanclkena_pal,
         pll_scandata => pll_reconfig_scandata_pal,
         pll_scandataout => pll_reconfig_scandataout,
         pll_scandone    => pll_reconfig_scandone,
         
         reconfig => pll_trigger_reconfig,
         reset => not(RESET_N)
     ); 

     process(RECONFIG_CLK,RESET_N)
     begin
        if (RESET_N='0') then
            pll_state_reg <= PLL_STATE_WAIT;
            pll_pause_counter_reg<= (others=>'0');
            pll_enable_reg<='0';
            reset_n_reg <= '0';
            
            reconfig_to_pal_reg <= '1';
            
        elsif (RECONFIG_CLK'event and RECONFIG_CLK='1') then
            pll_state_reg <= pll_state_next;
            pll_pause_counter_reg <= pll_pause_counter_next;
            pll_enable_reg <= pll_enable_next;
            reset_n_reg <= reset_n_next;        
    
            reconfig_to_pal_reg <= reconfig_to_pal_next;
        end if;
     end process;        
     
    pal_synchronizer : entity work.synchronizer
              port map (clk=>RECONFIG_CLK, raw=>pal, sync=>pal_fpga_sync);                   
     
    process (pll_state_reg, pal_fpga_sync, pll_pause_counter_reg,pll_enable_reg, PLL_LOCKED1, PLL_LOCKED, pll_reconfig_busy,reconfig_to_pal_reg)
    begin
              pll_state_next <= pll_state_reg;
              reset_n_next <= '1';
              reconfig_to_pal_next <= reconfig_to_pal_reg;
              
              pll_pause_counter_next <= std_logic_vector(unsigned(pll_pause_counter_reg)+1);                        

              pll_trigger_reconfig <= '0';
              pll_trigger_reconfig_downstream <= '0';
              pll_downstream_reset <= '0';
              pll_upstream_reset <= '0';
              
              pll_enable_next <= pll_enable_reg;                                                          

              case pll_state_reg is
                         when PLL_STATE_WAIT =>
                                    pll_enable_next <= '1';
                                    reset_n_next <= PLL_LOCKED;
                                    if (not(pal_fpga_sync = reconfig_to_pal_reg) and PLL_LOCKED='1' and PLL_LOCKED1='1') then
                                              reconfig_to_pal_next <= pal_fpga_sync;
                                              pll_state_next <= PLL_STATE_DISABLE;
                                              pll_enable_next <= '0';
                                    end if;

                                    
                         -- Wait for pll_enable_next to make through synchronizer
              when PLL_STATE_DISABLE =>        
                                    pll_state_next <= PLL_STATE_DISABLE_WAIT1;                                                    
                                    
              when PLL_STATE_DISABLE_WAIT1 =>        
                                    pll_state_next <= PLL_STATE_DISABLE_WAIT2;            

              when PLL_STATE_DISABLE_WAIT2 =>        
                                    pll_state_next <= PLL_STATE_DISABLE_WAIT3;

              when PLL_STATE_DISABLE_WAIT3 =>        
                                    pll_state_next <= PLL_STATE_DISABLE_WAIT4;                                        
                                    
              when PLL_STATE_DISABLE_WAIT4 =>        
                                    pll_state_next <= PLL_STATE_RECONFIG1;                                                
                                    
                         -- Set params for upstream pll and reset downstream pll
              when PLL_STATE_RECONFIG1 =>        
												pll_trigger_reconfig <= '1';
                                    pll_downstream_reset <= '1';
                                    pll_state_next <= PLL_STATE_RECONFIG1_WAIT_CONFIG;
                                                                         
              when PLL_STATE_RECONFIG1_WAIT_CONFIG =>        
                                    --pll_downstream_reset <= '1';
                                    if (pll_reconfig_busy = '0') then                                        
                                        pll_state_next <= PLL_STATE_RECONFIG1_WAIT_LOCK;
                                    end if;    

              when PLL_STATE_RECONFIG1_WAIT_LOCK =>
                                    --pll_downstream_reset <= '1';
                                    if (PLL_LOCKED1 = '1') then
                                        pll_state_next <= PLL_STATE_PAUSE1;
                                        pll_pause_counter_next <= (others=>'0');
                                        --pll_downstream_reset <= '0';
                                    end if;                    
                                
              when PLL_STATE_PAUSE1 =>
                                    if (pll_pause_counter_reg(24)='1') then
                                        pll_state_next <= PLL_STATE_WAIT;
                                    end if;                                        

              when others =>
                                    pll_state_next <= PLL_STATE_WAIT;

              end case;                 

    end process;

    reset_n_out <= reset_n_reg_sync;

    reset_synchronizer : entity work.synchronizer
              port map (clk=>CLK_RAW(SYNC_ON), raw=>reset_n_reg, sync=>reset_n_reg_sync); 

    pll_enable_synchronizer : entity work.synchronizer
              port map (clk=>CLK_RAW(SYNC_ON), raw=>pll_enable_reg, sync=>pll_enable_reg_sync); 
        
   GEN_CLKCTRL:
   for I in 0 to (CLOCKS-1) generate
        CLKCTRLX : entity work.clkctrl
        port map (
                inclk  => CLK_RAW(I),
                ena    => pll_enable_reg_sync,
                outclk => PLL_CLKS(I)
        );
   end generate GEN_CLKCTRL;

end vhdl;

