module test;
    reg clock = 0;
	reg reset = 1;

    integer i;
    integer fd;

    initial begin
        $readmemb("test.bin", core.memory);

		#10 reset = 0;

		#5000

        // Prints register state to file after execution
        fd = $fopen("test_out.txt", "w");
        for (i = 0; i < 32; i = i + 1) begin
            $fwrite(fd, "%x\n", core.iregs.regs[i]);
        end
		$finish;
	end

    always begin
        #5 clock = ~clock;
    end

    cpu core (
        .clk (clock),
		.reset (reset)
    );
endmodule