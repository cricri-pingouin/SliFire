Unit Unit1;

Interface

Uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, 
  MMSystem; //MMSystem for koystick

Type
  TForm1 = Class(TForm)
    Procedure FormActivate(Sender: TObject);
  Private
    { Private declarations }
  Public
    { Public declarations }
  End;

Var
  Form1: TForm1;

Implementation

{$R *.DFM}

{
Comment utiliser Scanline: http://lookinside.free.fr/delphi.php?Manipuler+des+pixels
Manipulating Pixels With Delphi's ScanLine Property: http://www.efg2.com/Lab/ImageProcessing/Scanline.htm
}

Procedure TForm1.FormActivate(Sender: TObject);
Var
  x, y, FireIntensity: Integer; //for loops
  PicBuffer: TBitmap; //buffer
  BufferArray: Array Of Array Of Byte; // Multi-dimension array
  PicWidth, PicHeight, PicH1, PicH2, PicH3, PicW1, PicW2, PicW3: Integer; //Declare variables to avoid repeatedly calling properties
  TempPixel: Byte; //Used to calculate pixels colour, then later reused to hold pixel colour in scanline
  P: PRGBTriple; //Scanline pointer
  Palette: Array[0..255] Of TRGBTriple; //24bits RGB palettes
  MyJoy: TJoyInfo;
Begin
  //See var declaration comment
  Form1.ClientWidth := 480;
  Form1.ClientHeight := 125;
  PicWidth := Form1.ClientWidth;
  PicHeight := Form1.ClientHeight + 3; //+3 to hide bottom pixels rows where fire seeded
  PicH1 := PicHeight - 1;
  PicH2 := PicHeight - 2;
  PicH3 := PicHeight - 3;
  PicW1 := PicWidth - 1;
  PicW2 := PicWidth - 2;
  PicW3 := PicWidth - 3;
  //Size the buffer array according to previous variables, i.e. form size
  SetLength(BufferArray, PicWidth, PicHeight);
  //Set palette
  //Initialise. otherwise unpredictable colours from whatever already in memory
  For x := 0 To 73 Do
  Begin
    Palette[x].rgbtRed := 0;
    Palette[x].rgbtGreen := 0;
    Palette[x].rgbtBlue := 0;
  End;
  //Flames blue top
  For x := 0 To 10 Do
  Begin
    Palette[x].rgbtBlue := x * 8;
    Palette[x + 10].rgbtBlue := 80 - x * 8;
  End;
  //Red gradient 0-256 for cold pixels
  For x := 10 To 41 Do
    Palette[x].rgbtRed := (x - 10) * 8;
  //Yellow gradient for warm pixels
  For x := 42 To 73 Do
  Begin
    Palette[x].rgbtRed := 255;
    Palette[x].rgbtGreen := (x - 42) * 8;
  End;
  //Yellow to white gradient for hot pixels, start with plain yellow and add blue to get white
  For x := 74 To 105 Do
  Begin
    Palette[x].rgbtRed := 255;
    Palette[x].rgbtGreen := 255;
    Palette[x].rgbtBlue := (x - 74) * 8;
  End;
  //Fill remaining palette with white
  For x := 106 To 255 Do
  Begin
    Palette[x].rgbtRed := 255;
    Palette[x].rgbtGreen := 255;
    Palette[x].rgbtBlue := 255;
  End;
  //Initialise buffer
  PicBuffer := TBitmap.Create;
  PicBuffer.Width := PicWidth;
  PicBuffer.Height := PicHeight;
  PicBuffer.PixelFormat := pf24bit; //Use 24bits RGB, not TColor as we won't use alpha blending
  FireIntensity := 80; //Default was 80 before joystick implementation
  //PicBuffer.Canvas.Brush.Color := clBlack; //Needed in SetPixel version, but apparently not in ScanLine version
  Repeat
    //Use joystick Y axis value to set flames intensity
    If joyGetPos(joystickid1, @MyJoy) = JOYERR_NOERROR Then
      FireIntensity := 100 - (MyJoy.wYpos Div 700);
    //Fill 3 bottom lines with random values
    For x := 0 To PicW1 Do
    Begin
      //Loop on Y would be more elegant but I suppose slower?
      BufferArray[x, PicH1] := Random(25) + FireIntensity;
      BufferArray[x, PicH2] := Random(25) + FireIntensity;
      BufferArray[x, PicH3] := Random(25) + FireIntensity;
    End;
    //Add random hot spots, i.e. 3x3 pure white "pixels"
    For x := 1 To 42 Do //Number of hot spots can be changed
    Begin
      //As above, loops on X&Y would be more elegant but probably slower
      y := Random(PicW3);
      BufferArray[y, PicH1] := 255;
      BufferArray[y, PicH2] := 255;
      BufferArray[y, PicH3] := 255;
      BufferArray[y + 1, PicH1] := 255;
      BufferArray[y + 1, PicH2] := 255;
      BufferArray[y + 1, PicH3] := 255;
      BufferArray[y + 2, PicH1] := 255;
      BufferArray[y + 2, PicH2] := 255;
      BufferArray[y + 2, PicH3] := 255;
    End;
    //Calculate pixels
    For x := 1 To PicW2 Do
      For y := 1 To PicH2 Do
      Begin
        //Use of a temp variable to avoid redundant accesses to the table
        //Use the neighbours of the pixels below, by using y-2, y-1 and y as opposed to y-1, y, y+1
        //This combines raising flames with pixel computation based on neighbours
        TempPixel := (BufferArray[x - 1, y + 2] + BufferArray[x, y + 2] + BufferArray[x + 1, y + 2] + BufferArray[x - 1, y + 1] + BufferArray[x, y + 1] + BufferArray[x + 1, y + 1] + BufferArray[x - 1, y] + BufferArray[x + 1, y]) Shr 3; // div 8;
        //Decrease pixel temperature; disabling this makes for higher flames but not as realistic
        If TempPixel > 0 Then
          Dec(TempPixel);
        BufferArray[x, y] := TempPixel;
      End;
    //Populate buffer
    For y := 0 To PicH1 Do //Height-1 or pointer will fall out=crash!
    Begin
      //Loop through Y, then X. This way we process the whole scanline in one go
      P := PicBuffer.ScanLine[y];
      For x := 0 To PicW1 Do //Width-1 or pointer will fall out=crash!
      Begin
        //Set pixel colour according to index value in palettes
        P^ := Palette[BufferArray[x, y]];
        //Increment pointer AFTER, otherwise we fail to process leftmost column
        Inc(P);
      End;
    End;
    //Copy buffer to form canvas
    Canvas.Draw(0, 0, PicBuffer);
    //Do not hog CPU
    Application.Processmessages;
    Sleep(20);
  Until Application.Terminated;
  //Free PicBuffer to avoid memory leak
  PicBuffer.Free;
End;

End.

