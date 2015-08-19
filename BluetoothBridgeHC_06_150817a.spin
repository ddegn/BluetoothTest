DAT programName         byte "BluetoothBridgeHC_05_150817b", 0
CON
{{
  By Duane Degn
  August 17, 2015

  
}}
{
  ******* Private Notes *******
  
}  
CON

  _clkmode = xtal1 + pll16x                           
  _xinfreq = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq
  MILLISECOND = CLK_FREQ / 1_000

  '' I/O pins
  'RX2     = 11                                             
  'TX2     = 10
  BLUETOOTH_KEY = 14
  BLUETOOTH_TX = 15
  BLUETOOTH_RX = 16
  
  I2C_CLOCK = 9
  I2C_DATA = 10
  'BLUETOOTH_RX = I2C_CLOCK
  'BLUETOOTH_TX = I2C_DATA

  TX_TO_BT = BLUETOOTH_TX 
  RX_FROM_BT = BLUETOOTH_RX 


  PST_BAUD = 115_200           
  BT_BAUD = 115_200 '38_400 '  
           
  CHANGE_BAUD_CHARACTER = "&"   ' Use this character to enter new baud for Bluetooth communication.
  SET_KEY_LOW = "\"
  SET_KEY_HIGH = "|"
  BT_SERIAL_MODE = 0 '%1000
  
VAR

  long btBaud
  
  byte btBuffer[Bt#BUFFER_LENGTH + 1]
  
OBJ

  Pst : "Parallax Serial Terminal"
  Bt : "Parallax Serial Terminal"
  Format : "StrFmt"
  
PUB Start

  outa[BLUETOOTH_KEY] := 0
  dira[BLUETOOTH_KEY] := 1

  
  btBaud := BT_BAUD
  Pst.Start(PST_BAUD)
  Bt.StartRxTx(RX_FROM_BT, TX_TO_BT, BT_SERIAL_MODE, btBaud)
  
  BridgeBt

PUB BridgeBt | inputCharacter, numberOfCharactersInBuffer, btIndex

  btIndex := 0
  
  repeat
    '' This first section of the loop checks for input from the terminal.
    '' If input is received it is passed on to the Bt only after
    '' a chariage return is received.
    '' The BT message is terminated with a both a carriage return
    '' and a line feed.

    numberOfCharactersInBuffer := Pst.RxCount
    if numberOfCharactersInBuffer
      repeat numberOfCharactersInBuffer
        inputCharacter := Pst.CharIn
        btBuffer[btIndex++] := inputCharacter
        case inputCharacter
          $0D: ' Add a line feed character when a carriage return is received.
            btBuffer[btIndex++] := $0A
            btBuffer[btIndex] := 0
            Bt.Str(@btBuffer)
            Pst.Str(string(11, 13, "Sent following string to Bluetooth: "))
            SafeStr(@btBuffer, btIndex)
            btIndex := 0    

          CHANGE_BAUD_CHARACTER:
            Pst.Str(string(11, 13, "Enter new Bluetooth baud: "))
            btBaud := Pst.DecIn
            Pst.Str(string(11, 13, "New Bluetooth baud = "))
            Pst.Dec(btBaud)
            Bt.StartRxTx(RX_FROM_BT, TX_TO_BT, BT_SERIAL_MODE, btBaud) 
          SET_KEY_LOW:
            outa[BLUETOOTH_KEY] := 0
          SET_KEY_HIGH:
            outa[BLUETOOTH_KEY] := 1
                   
    '' This last section of the loop checks for input from the Bt.
    '' If input is received it is passed on to the terminal.
    '' Non-printable ASCII characters will be displayed as their
    '' hexadecimal value.
    
    numberOfCharactersInBuffer := Bt.RxCount
    if numberOfCharactersInBuffer
      repeat numberOfCharactersInBuffer
        inputCharacter := Bt.CharIn
        SafeTx(inputCharacter)

PRI SafeStr(localPtr, localSize)

  repeat localSize
    SafeTx(byte[localPtr++])
    
PRI SafeTx(localCharacter)

  if localCharacter => 32 and localCharacter =< "~"
    Pst.Char(localCharacter)
  elseif localCharacter == 0 ' this may need to be changed if monitoring raw data
                             ' "Parallax Serial Terminal" doesn't catch framing errors
                             ' so without this "elseif" line you can end up with a
                             ' bunch of zeros if a line is inactive. 
    return
  else
    Pst.Char("<") 
    Pst.Char("$")
    Pst.Hex(localCharacter, 2)
    Pst.Char(">")

  if localCharacter == $0D ' The hex value of carriage return characters will be displayed
    Pst.Char($0D)         ' and the carriage return will also be passed to the terminal.
                           ' This should improve the readablity of the output.

                        