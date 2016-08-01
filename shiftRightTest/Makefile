
TARGET = top

$(TARGET).bin: $(TARGET).txt
	icepack $(TARGET).txt $(TARGET).bin

#$(TARGET).blif: *.v
#	yosys -q -p "synth_ice40 -blif $(TARGET).blif" *.v
$(TARGET).blif: ../canUnstuff.v ../spiSlave.v trivialCapture.v top.v
	yosys -q -p "synth_ice40 -blif $(TARGET).blif" ../canUnstuff.v ../spiSlave.v trivialCapture.v top.v

$(TARGET).txt: $(TARGET).blif ../*.pcf 
	arachne-pnr -d 1k -p ../*.pcf $(TARGET).blif -o $(TARGET).txt

$(TARGET).ex: $(TARGET).txt
	icebox_explain $(TARGET).txt > $(TARGET).ex

explain: $(TARGET).ex

upload: $(TARGET).bin
	iceprog $(TARGET).bin

clean:
	rm -f $(TARGET).blif $(TARGET).txt $(TARGET).ex $(TARGET).bin
