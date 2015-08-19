DAT programName         byte "EddieBtInderface", 0
CON
{{
  By Duane Degn
  July 18, 2015

  
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
 
  TX_TO_BT = 15              
  RX_FROM_BT = 16             
  ENABLE = 14
  
  '' The FONA should be powered from a single cell LiPo battery. The ground
  '' of the FONA should be connected to the ground of the Propeller.
  '' 3.3V should be connected to the FONA's Vio pin.

  PST_BAUD = 115_200           
  BT_BAUD = 9_600 ' 38_400 '

  END_OF_SMS_CHARACTER = "~"    ' This should a character not used by the FONA in normal communication.
  CONTROL_Z = 26                
  CHANGE_BAUD_CHARACTER = "&"
  
  BT_SERIAL_MODE = 0 '%1000

  DATA_FIELD_SIZE = 16
  
VAR

  long btBaud
  long dataPtr[4]
  long joyX, joyY
  
  byte btBuffer[Bt#BUFFER_LENGTH + 1]
  byte button[6]
  
OBJ

  Pst : "Parallax Serial Terminal"
  Bt : "Parallax Serial Terminal"
  'Format : "StrFmt"
  
PUB Start

  dataPtr[0] := @data0
  dataPtr[1] := @data1
  dataPtr[2] := @data2
  dataPtr[3] := @data3
  
  btBaud := BT_BAUD
  Pst.Start(PST_BAUD)
  Bt.StartRxTx(RX_FROM_BT, TX_TO_BT, BT_SERIAL_MODE, btBaud)
  
  BridgeBt

PUB BridgeBt | inputCharacter, numberOfCharactersInBuffer, btIndex

  btIndex := 0
  
  repeat
    '' This first section of the loop checks for input from the terminal.
    '' If input is received it is passed on to the Bt.
    '' If the character defined by "END_OF_SMS_CHARACTER" is received
    '' a control-Z character will be substituted by the program.
    '' This is not a way to directly send a control-Z character
    '' from Parallax Serial Terminal.exe.
    
    numberOfCharactersInBuffer := Pst.RxCount
    if numberOfCharactersInBuffer
      repeat numberOfCharactersInBuffer
        inputCharacter := Pst.CharIn
        if inputCharacter == "d" 
          SendData
          quit
        elseif inputCharacter => "1" and inputCharacter =< "3"
          GetData(inputCharacter - "0")
          quit
        elseif inputCharacter == CHANGE_BAUD_CHARACTER
          Pst.RxFlush
          Bt.RxFlush
          ChangeBaud
          btIndex := 0
          quit
        elseif inputCharacter == END_OF_SMS_CHARACTER
          inputCharacter := CONTROL_Z
        btBuffer[btIndex++] := inputCharacter
          
        'Bt.Char(inputCharacter)
        if inputCharacter == $0D ' Add a line feed character when a carriage return is received.
          btBuffer[btIndex++] := $0A
          btBuffer[btIndex] := 0
          Bt.Str(@btBuffer)
          Pst.Str(string(11, 13, "Sent following string to Bluetooth: "))
          SafeStr(@btBuffer, btIndex)
          'Bt.Char($0A)         ' This step isn't really needed since the FONA will work fine
                                 ' with just a carriage return.
                                 
          btIndex := 0                       
    '' This last section of the loop checks for input from the Bt.
    '' If input is received it is passed on to the terminal.
    '' Non-printable ASCII characters will be displayed as their
    '' hexadecimal value.
    
    numberOfCharactersInBuffer := Bt.RxCount
    if numberOfCharactersInBuffer
      repeat numberOfCharactersInBuffer
        inputCharacter := Bt.CharIn
        if inputCharacter == 2
          ReceiveState
        else
          SafeTx(inputCharacter)

PUB ReceiveState | inputCharacter


  inputCharacter := Bt.CharIn
  case inputCharacter
    "A".."L":
      inputCharacter -= "A"
      button[inputCharacter / 2] := inputCharacter // 2
      if button[inputCharacter / 2]
        data0[inputCharacter / 2] := "0"
      else
        data0[inputCharacter / 2] := "1"
    other:
      ReceiveJoystick(inputCharacter)
    
  inputCharacter := Bt.CharIn

  Pst.Home
  Pst.Str(string(11, 13, "joyX = "))
  Pst.Dec(joyX)
  Pst.Str(string(11, 13, "joyY = "))
  Pst.Dec(joyY)
  Pst.Str(string(11, 13, "buttons = "))
  Pst.Str(@data0)
  Pst.Str(string(11, 13, "data = "))
  Pst.Str(@data1)
  Pst.Str(string(", "))
  Pst.Str(@data2)
  Pst.Str(string(", "))
  Pst.Str(@data3)
  Pst.ClearEnd
  
  if inputCharacter <> 3
    Pst.Str(string(11, 13, "Error, expected to receive end of message character.")) 

PUB ReceiveJoystick(inputCharacter)

  result := inputCharacter - "0"
  repeat 2
    result *= 10
    inputCharacter := Bt.CharIn  
    result += inputCharacter - "0"

  joyX := result - 200
  result := 0
  
  repeat 3
    result *= 10
    inputCharacter := Bt.CharIn  
    result += inputCharacter - "0"

  joyY := result - 200
    
PRI ChangeBaud

  Bt.Stop
  Pst.Str(string(11, 13, "Please enter new baud for Bluetooth."))
  btBaud := Pst.DecIn
  Pst.Str(string(11, 13, "The Bluetooth baud is now "))
  Pst.Dec(btBaud)
  Pst.Str(string(" bps")) 
  Bt.StartRxTx(RX_FROM_BT, TX_TO_BT, BT_SERIAL_MODE, btBaud)
  waitcnt(clkfreq / 20 + cnt)
  
PRI GetData(fieldId)

  Pst.Str(string(11, 13, "Please enter data for field # "))
  Pst.Dec(fieldId)
  Pst.StrInMax(dataPtr[fieldId], DATA_FIELD_SIZE)
  SendData
  
PRI SendData

  repeat result from 0 to 3
    Bt.Char(controlChar[result])
    Bt.Str(dataPtr[result])
    
  Bt.Char(controlChar[4])
  
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

DAT
                             
data0         byte "110101", 0
                   '1234567890123456
data1         byte "-1500", 0[DATA_FIELD_SIZE - 5]
data2         byte "123.456", 0[DATA_FIELD_SIZE - 7]
data3         byte "Motors Enabled", 0[DATA_FIELD_SIZE - 14]

controlChar   byte 2, 1, 4, 5, 3                         