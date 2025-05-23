unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  LCLIntf, LCLType, uplaysound,  LazJPG, LazTGA    ;

// --- Costanti ---
const
  GRID_WIDTH = 10;
  GRID_HEIGHT = 20;
  CELL_SIZE = 30;

// --- Colori associati ai pezzi (Pascal TColor) ---
const
  COLORS: array[0..6] of TColor = (
    clAqua,    // I - cyan
    clYellow,  // O - yellow
    clPurple,  // T - purple
    clGreen,   // S - green
    clRed,     // Z - red
    $0000A5FF, // L - orange (valore BGR per arancione)
    clBlue     // J - blue
  );

// --- Tipi personalizzati per la griglia e le forme ---
type
  TCellColor = LongInt;
  TGrid = array[0..GRID_HEIGHT-1, 0..GRID_WIDTH-1] of TCellColor;
  TShapeMatrix = array of array of Integer;

  // NUOVO: Tipo enumerativo per gli stati del gioco
  TGameMode = (gmMenu, gmPlaying, gmGameOver);

  { TForm1 }

  TForm1 = class(TForm)
    CanvasPanel: TImage;
    playsound1: Tplaysound;
    ScoreLabel: TLabel;
    GameTimer: TTimer;


    procedure CanvasPanelClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    // RIMOSSO: procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure GameTimerTimer(Sender: TObject);
    procedure CanvasPanelPaint(Sender: TObject);

  private
    FGrid: TGrid;
    FScore: Integer;
    FGameOver: Boolean;
    FCurrentPiece: TShapeMatrix;
    FCurrentPieceX, FCurrentPieceY: Integer;
    FCurrentPieceColor: TColor;
    FCurrentPieceIndex: Integer;

    FShapesData: array[0..6] of TShapeMatrix;

    // NUOVO: Variabili per il menu
    FGameMode: TGameMode; // Stato attuale del gioco
    FMenuOptions: array[0..3] of String; // Opzioni del menu: Gioca, Record, Esci
    FSelectedMenuOption: Integer; // Opzione selezionata nel menu

    FSfondo: TBitmap; // Variabile per l'immagine di sfondo
    FSfondoJPEG : TJPGImage;

    procedure Restart;
    procedure NewPiece;
    function CheckCollision(const Piece: TShapeMatrix; OffsetX, OffsetY: Integer): Boolean;
    procedure MergePiece;
    procedure ClearLines;
    procedure RotatePiece;
    procedure MovePiece(dx, dy: Integer);
    procedure DropPiece;
    procedure UpdateGame;
    procedure DrawGame;

    // NUOVO: Procedura per mostrare il menu
    procedure ShowMenu;

  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

// --- Implementazione dei metodi della Form ---

procedure TForm1.FormCreate(Sender: TObject);

var
  SfondoPath: String;
begin
  // Inizializza le forme dei pezzi come array dinamici
  SetLength(FShapesData[0], 1); SetLength(FShapesData[0][0], 4);
  FShapesData[0][0,0] := 1; FShapesData[0][0,1] := 1; FShapesData[0][0,2] := 1; FShapesData[0][0,3] := 1;

  SetLength(FShapesData[1], 2); SetLength(FShapesData[1][0], 2); SetLength(FShapesData[1][1], 2);
  FShapesData[1][0,0] := 1; FShapesData[1][0,1] := 1;
  FShapesData[1][1,0] := 1; FShapesData[1][1,1] := 1;

  SetLength(FShapesData[2], 2); SetLength(FShapesData[2][0], 3); SetLength(FShapesData[2][1], 3);
  FShapesData[2][0,0] := 0; FShapesData[2][0,1] := 1; FShapesData[2][0,2] := 0;
  FShapesData[2][1,0] := 1; FShapesData[2][1,1] := 1; FShapesData[2][1,2] := 1;

  SetLength(FShapesData[3], 2); SetLength(FShapesData[3][0], 3); SetLength(FShapesData[3][1], 3);
  FShapesData[3][0,0] := 1; FShapesData[3][0,1] := 1; FShapesData[3][0,2] := 0;
  FShapesData[3][1,0] := 0; FShapesData[3][1,1] := 1; FShapesData[3][1,2] := 1;

  SetLength(FShapesData[4], 2); SetLength(FShapesData[4][0], 3); SetLength(FShapesData[4][1], 3);
  FShapesData[4][0,0] := 0; FShapesData[4][0,1] := 1; FShapesData[4][0,2] := 1;
  FShapesData[4][1,0] := 1; FShapesData[4][1,1] := 1; FShapesData[4][1,2] := 0;

  SetLength(FShapesData[5], 2); SetLength(FShapesData[5][0], 3); SetLength(FShapesData[5][1], 3);
  FShapesData[5][0,0] := 1; FShapesData[5][0,1] := 0; FShapesData[5][0,2] := 0;
  FShapesData[5][1,0] := 1; FShapesData[5][1,1] := 1; FShapesData[5][1,2] := 1;

  SetLength(FShapesData[6], 2); SetLength(FShapesData[6][0], 3); SetLength(FShapesData[6][1], 3);
  FShapesData[6][0,0] := 0; FShapesData[6][0,1] := 0; FShapesData[6][0,2] := 1;
  FShapesData[6][1,0] := 1; FShapesData[6][1,1] := 1; FShapesData[6][1,2] := 1;

  // Imposta le dimensioni del CanvasPanel
  CanvasPanel.Width := GRID_WIDTH * CELL_SIZE;
  CanvasPanel.Height := GRID_HEIGHT * CELL_SIZE;

  // Imposta le proprietà del Timer
  GameTimer.Interval := 500;
  GameTimer.Enabled := False; // Il timer è disabilitato finché il gioco non inizia

  Randomize; // Inizializza il generatore di numeri casuali

  // NUOVO: Inizia in modalità menu
  FGameMode := gmMenu;
  FMenuOptions[0] := 'Gioca';
  FMenuOptions[1] := 'Record'; // Non implementato, ma per mostrare l'opzione
  FMenuOptions[2] := 'About';
  FMenuOptions[3] := 'Esci';
  FSelectedMenuOption := 0; // Seleziona la prima opzione di default

    // Carica l'immagine di sfondo
  //FSfondo := TBitmap.Create; // Crea un'istanza di TBitmap
  SfondoPath := ExtractFilePath(Application.ExeName) + 'image' + PathDelim + 'sfondo1.jpg'; // Costruisce il percorso


   FSfondoJPEG:=TJPGImage.Create;

    if FileExists(ExtractFilePath(Application.ExeName) + 'sound\vie.wav') then
    begin

       PlaySound1.SoundFile:=PChar(ExtractFilePath(Application.ExeName) + 'sound\vie.wav');

    end;



  if FileExists(SfondoPath) then
  begin
    try
      FSfondoJPEG.LoadFromFile(SfondoPath); // Carica l'immagine
    except
      on E: Exception do
        ShowMessage('Errore nel caricamento sfondo: ' + E.Message);
    end;
  end
  else
  begin
    ShowMessage('File sfondo1.jpg non trovato in: ' + SfondoPath);
  end;

  DrawGame; // Disegna il menu iniziale
end;

procedure TForm1.CanvasPanelClick(Sender: TObject);
var
  i: Integer;
  TextWidth, TextHeight: Integer;
  MenuX, MenuY: Integer;
  OptionRect: TRect;
  ScreenMousePos: TPoint; // Per le coordinate del mouse sullo schermo
  PanelMousePos: TPoint;  // Per le coordinate del mouse relative al CanvasPanel
begin
  // Gestiamo il click solo in modalità menu
  if FGameMode = gmMenu then
  begin
    // Ottieni le coordinate attuali del cursore sullo schermo
    GetCursorPos(ScreenMousePos);
    // Converti le coordinate dello schermo in coordinate relative al CanvasPanel
    PanelMousePos := CanvasPanel.ScreenToClient(ScreenMousePos);

    // Calcola le dimensioni e la posizione delle opzioni del menu in modo simile a ShowMenu
    CanvasPanel.Canvas.Font.Assign(ScoreLabel.Font);
    CanvasPanel.Canvas.Font.Size := 24; // Deve corrispondere alla dimensione usata in ShowMenu

    MenuY := (CanvasPanel.Height div 2) - 50; // Posizione Y iniziale per le opzioni

    for i := Low(FMenuOptions) to High(FMenuOptions) do
    begin
      TextWidth := CanvasPanel.Canvas.TextWidth(FMenuOptions[i]);
      TextHeight := CanvasPanel.Canvas.TextHeight(FMenuOptions[i]); // Ottieni l'altezza del testo

      MenuX := (CanvasPanel.Width div 2) - (TextWidth div 2);

      // Definisci l'area rettangolare per l'opzione
      OptionRect := Rect(MenuX, MenuY, MenuX + TextWidth, MenuY + TextHeight);

      // Controlla se il click (PanelMousePos.X, PanelMousePos.Y) è all'interno di questa area
      if PtInRect(OptionRect, PanelMousePos) then
      begin
        FSelectedMenuOption := i; // Aggiorna l'opzione selezionata (per l'evidenziazione visiva)
        DrawGame; // Ridisegna per mostrare la selezione

        // Esegui l'azione associata all'opzione cliccata
        case FSelectedMenuOption of
          0: Restart; // Gioca
          1: ShowMessage('Funzione Record non implementata.'); // Record
          2: ShowMessage('Funzione About non implementata.'); // About
          3: Close; // Esci
        end;
        Exit; // Esci dal ciclo una volta trovata l'opzione cliccata
      end;
      Inc(MenuY, 40); // Sposta la prossima opzione più in basso (deve corrispondere a ShowMenu)
    end;
  end;
end;


procedure TForm1.FormDestroy(Sender: TObject);
begin
      if Assigned(FSfondoJPEG) then
  begin
    FSfondoJPEG.Free; // Libera la memoria dell'immagine
    FSfondoJPEG := nil; // Imposta a nil per sicurezza
  end;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case FGameMode of
    gmMenu:
      begin
        case Key of
          VK_UP: // Freccia SU
            begin
              FSelectedMenuOption := FSelectedMenuOption - 1;
              if FSelectedMenuOption < Low(FMenuOptions) then
                FSelectedMenuOption := High(FMenuOptions);
              DrawGame;
            end;
          VK_DOWN: // Freccia GIÙ
            begin
              FSelectedMenuOption := FSelectedMenuOption + 1;
              if FSelectedMenuOption > High(FMenuOptions) then
                FSelectedMenuOption := Low(FMenuOptions);
              DrawGame;
            end;
          VK_RETURN: // INVIO
            begin
              case FSelectedMenuOption of
                0: Restart; // Gioca
                1: ShowMessage('Funzione Record non implementata.'); // Record
                2: ShowMessage('Funzione About non implementata.'); // Record
                3: Close; // Esci
              end;
            end;
          VK_ESCAPE: // ESC
            Close;
        end;
      end;
    gmPlaying:
      begin
        if FGameOver then Exit;
        case Key of
          VK_LEFT: MovePiece(-1, 0); // Freccia sinistra
          VK_RIGHT: MovePiece(1, 0); // Freccia destra
          VK_DOWN: MovePiece(0, 1); // Freccia giù
          VK_UP: RotatePiece; // Freccia su
          VK_SPACE: DropPiece; // Spazio
        end;
      end;
    gmGameOver:
      begin
        // Gestiamo 'R' qui, usando Char(Key) che è convertito a maiuscolo
        if (Key = Ord('R')) then // Usiamo Ord('R') perché Key è di tipo Word
        begin
          FGameMode := gmMenu; // Torna al menu dopo Game Over
          DrawGame; // Disegna il menu
        end;
      end;
  end;
end;

// RIMOSSO:
// procedure TForm1.FormKeyPress(Sender: TObject; var Key: Char);
// begin
//   // Questa procedura sarà completamente rimossa
// end;

procedure TForm1.Restart;
var
  r, c: Integer;
begin
  // Inizializza la griglia a vuoto (0)
  for r := 0 to GRID_HEIGHT - 1 do
    for c := 0 to GRID_WIDTH - 1 do
      FGrid[r, c] := 0;

  FScore := 0;
  FGameOver := False;
  FCurrentPiece := nil;
  FCurrentPieceX := 0;
  FCurrentPieceY := 0;
  FCurrentPieceIndex := 0;

  ScoreLabel.Caption := 'Score: ' + IntToStr(FScore);
  CanvasPanel.Canvas.FillRect(0, 0, CanvasPanel.Width, CanvasPanel.Height);

  FGameMode := gmPlaying; // NUOVO: Imposta la modalità di gioco
  NewPiece;
  GameTimer.Enabled := True;
end;

procedure TForm1.NewPiece;
var
  PieceWidth, PieceHeight: Integer;
begin
  if not FGameOver then
  begin
    FCurrentPieceIndex := Random(High(FShapesData) + 1); // Sceglie un indice casuale
    FCurrentPiece := FShapesData[FCurrentPieceIndex]; // Assegna la forma del pezzo
    FCurrentPieceColor := COLORS[FCurrentPieceIndex]; // Assegna il colore

    // Aggiungi controlli di lunghezza robusti qui, come discusso in precedenza.
    // Anche se ora dovrebbe essere stabile, è una buona pratica di difesa.
    if (Length(FCurrentPiece) > 0) and (Length(FCurrentPiece[0]) > 0) then
      PieceWidth := Length(FCurrentPiece[0])
    else
      PieceWidth := 0; // Se per qualche motivo il pezzo è malformato, evita errori

    FCurrentPieceX := GRID_WIDTH div 2 - PieceWidth div 2;
    FCurrentPieceY := 0;

    if CheckCollision(FCurrentPiece, FCurrentPieceX, FCurrentPieceY) then
    begin
      FGameOver := True;
      FGameMode := gmGameOver; // NUOVO: Imposta la modalità Game Over
      GameTimer.Enabled := False;
      DrawGame; // Disegna lo stato finale
    end
    else
    begin
      DrawGame;
    end;
  end;
end;

function TForm1.CheckCollision(const Piece: TShapeMatrix; OffsetX, OffsetY: Integer): Boolean;
var
  r, c: Integer;
  Px, Py: Integer;
begin
  Result := False;
  if Piece = nil then Exit;

  for r := 0 to High(Piece) do
  begin
    for c := 0 to High(Piece[r]) do
    begin
      if Piece[r, c] <> 0 then
      begin
        Px := OffsetX + c;
        Py := OffsetY + r;

        if (Px < 0) or (Px >= GRID_WIDTH) or (Py >= GRID_HEIGHT) then
        begin
          Result := True;
          Exit;
        end;

        if (Py >= 0) and (FGrid[Py, Px] <> 0) then
        begin
          Result := True;
          Exit;
        end;
      end;
    end;
  end;
end;

procedure TForm1.MergePiece;
var
  r, c: Integer;
begin
  if FCurrentPiece = nil then Exit;

  for r := 0 to High(FCurrentPiece) do
  begin
    for c := 0 to High(FCurrentPiece[r]) do
    begin
      if FCurrentPiece[r, c] <> 0 then
      begin
        FGrid[FCurrentPieceY + r, FCurrentPieceX + c] := FCurrentPieceColor;
      end;
    end;
  end;
end;



procedure TForm1.ClearLines;
var
  r, c: Integer;
  NewGrid: TGrid;
  LinesCleared: Integer;
  NewRowIndex: Integer;
  IsRowFull: Boolean;
begin
  LinesCleared := 0;
  NewRowIndex := GRID_HEIGHT - 1;

  for r := 0 to GRID_HEIGHT - 1 do
    for c := 0 to GRID_WIDTH - 1 do
      NewGrid[r, c] := 0;

  for r := GRID_HEIGHT - 1 downto 0 do
  begin
    IsRowFull := True;
    for c := 0 to GRID_WIDTH - 1 do
    begin
      if FGrid[r, c] = 0 then
      begin
        IsRowFull := False;
        Break;
      end;
    end;

    if not IsRowFull then
    begin
      // Copia la riga nel nuovo grid
      for c := 0 to GRID_WIDTH - 1 do
        NewGrid[NewRowIndex, c] := FGrid[r, c];
      Dec(NewRowIndex);
    end
    else
    begin
      // Riga piena, viene cancellata → suona!
      Inc(LinesCleared);
      PlaySound1.Execute; // Riproduce il suono esattamente qui, per ogni riga cancellata
    end;
  end;

  FGrid := NewGrid;

  FScore := FScore + (LinesCleared * LinesCleared);
  ScoreLabel.Caption := 'Score: ' + IntToStr(FScore);
end;



procedure TForm1.RotatePiece;
var
  RotatedPiece: TShapeMatrix;
  oldR, oldC, newR, newC: Integer;
  PieceHeight, PieceWidth: Integer;
begin
  if FCurrentPiece = nil then Exit;

  PieceHeight := Length(FCurrentPiece);
  PieceWidth := Length(FCurrentPiece[0]);

  SetLength(RotatedPiece, PieceWidth);
  for newR := 0 to PieceWidth - 1 do
    SetLength(RotatedPiece[newR], PieceHeight);

  for oldR := 0 to PieceHeight - 1 do
  begin
    for oldC := 0 to PieceWidth - 1 do
    begin
      newR := oldC;
      newC := (PieceHeight - 1) - oldR;
      if (newR >= 0) and (newR < Length(RotatedPiece)) and
           (newC >= 0) and (newC < Length(RotatedPiece[newR])) then
      begin
        RotatedPiece[newR, newC] := FCurrentPiece[oldR, oldC];
      end;
    end;
  end;

  if not CheckCollision(RotatedPiece, FCurrentPieceX, FCurrentPieceY) then
  begin
    FCurrentPiece := RotatedPiece;
    DrawGame;
  end;
end;

procedure TForm1.MovePiece(dx, dy: Integer);
begin
  if FCurrentPiece = nil then Exit;
  if not FGameOver then
  begin
    if not CheckCollision(FCurrentPiece, FCurrentPieceX + dx, FCurrentPieceY + dy) then
    begin
      FCurrentPieceX := FCurrentPieceX + dx;
      FCurrentPieceY := FCurrentPieceY + dy;
      DrawGame;
    end;
  end;
end;

procedure TForm1.DropPiece;
begin
  if FCurrentPiece = nil then Exit;
  if not FGameOver then
  begin
    while not CheckCollision(FCurrentPiece, FCurrentPieceX, FCurrentPieceY + 1) do
    begin
      FCurrentPieceY := FCurrentPieceY + 1;
    end;
    MergePiece;
    ClearLines;
    NewPiece;
    DrawGame;
  end;
end;

procedure TForm1.UpdateGame;
begin
  if FCurrentPiece = nil then Exit;
  if not FGameOver then
  begin
    if not CheckCollision(FCurrentPiece, FCurrentPieceX, FCurrentPieceY + 1) then
    begin
      FCurrentPieceY := FCurrentPieceY + 1;
    end else
      begin
        MergePiece;
        ClearLines;
        NewPiece;
      end;
    DrawGame;
  end;
end;

procedure TForm1.DrawGame;
var
  r, c: Integer;
  RectLeft, RectTop, RectRight, RectBottom: Integer;
begin
  // Disegna l'immagine di sfondo per pulire il canvas
  if Assigned(FSfondoJPEG) and (FSfondoJPEG.Width > 0) and (FSfondoJPEG.Height > 0) then
  begin
    // Disegna l'immagine, scalando se necessario per riempire il CanvasPanel
    CanvasPanel.Canvas.StretchDraw(
      Rect(0, 0, CanvasPanel.Width, CanvasPanel.Height),
      FSfondoJPEG
    );
  end
  else
  begin
    // Se lo sfondo non è stato caricato, usa un colore solido (come facevi prima)
    CanvasPanel.Canvas.Brush.Color := clBlack;
    CanvasPanel.Canvas.FillRect(0, 0, CanvasPanel.Width, CanvasPanel.Height);
  end;


  // Disegna in base alla modalità di gioco
  case FGameMode of
    gmMenu:
      ShowMenu; // Disegna il menu (che sovrascriverà lo sfondo)
    gmPlaying:
      begin
        // ... (il tuo codice esistente per disegnare la griglia e il pezzo) ...
        // Disegna i blocchi fissi nella griglia
        for r := 0 to GRID_HEIGHT - 1 do
        begin
          for c := 0 to GRID_WIDTH - 1 do
          begin
            if FGrid[r, c] <> 0 then
            begin
              RectLeft := c * CELL_SIZE;
              RectTop := r * CELL_SIZE;
              RectRight := (c + 1) * CELL_SIZE;
              RectBottom := (r + 1) * CELL_SIZE;

              CanvasPanel.Canvas.Brush.Color := FGrid[r, c];
              CanvasPanel.Canvas.Pen.Color := clWhite;
              CanvasPanel.Canvas.Rectangle(RectLeft, RectTop, RectRight, RectBottom);
            end;
          end;
        end;

        // Disegna il pezzo corrente
        if (FCurrentPiece <> nil) and not FGameOver then
        begin
          for r := 0 to High(FCurrentPiece) do
          begin
            for c := 0 to High(FCurrentPiece[r]) do
            begin
              if FCurrentPiece[r, c] <> 0 then
              begin
                RectLeft := (FCurrentPieceX + c) * CELL_SIZE;
                RectTop := (FCurrentPieceY + r) * CELL_SIZE;
                RectRight := (FCurrentPieceX + c + 1) * CELL_SIZE;
                RectBottom := (FCurrentPieceY + r + 1) * CELL_SIZE;

                CanvasPanel.Canvas.Brush.Color := FCurrentPieceColor;
                CanvasPanel.Canvas.Pen.Color := clWhite;
                CanvasPanel.Canvas.Rectangle(RectLeft, RectTop, RectRight, RectBottom);
              end;
            end;
          end;
        end;
      end;
    gmGameOver:
      begin
        // ... (il tuo codice esistente per disegnare la griglia e il testo Game Over) ...
        // Disegna la griglia finale (sulla base dello sfondo)
        for r := 0 to GRID_HEIGHT - 1 do
        begin
          for c := 0 to GRID_WIDTH - 1 do
          begin
            if FGrid[r, c] <> 0 then
            begin
              RectLeft := c * CELL_SIZE;
              RectTop := r * CELL_SIZE;
              RectRight := (c + 1) * CELL_SIZE;
              RectBottom := (r + 1) * CELL_SIZE;

              CanvasPanel.Canvas.Brush.Color := FGrid[r, c];
              CanvasPanel.Canvas.Pen.Color := clWhite;
              CanvasPanel.Canvas.Rectangle(RectLeft, RectTop, RectRight, RectBottom);
            end;
          end;
        end;

        // Disegna il testo Game Over (sopra lo sfondo e la griglia)
        CanvasPanel.Canvas.Font.Assign(ScoreLabel.Font);
        CanvasPanel.Canvas.Font.Size := 36;
        CanvasPanel.Canvas.Font.Color := clRed;
        CanvasPanel.Canvas.TextOut(
          (GRID_WIDTH * CELL_SIZE div 2) - (CanvasPanel.Canvas.TextWidth('GAME OVER') div 2),
          (GRID_HEIGHT * CELL_SIZE div 2) - 30,
          'GAME OVER'
        );
        CanvasPanel.Canvas.Font.Size := 16;
        CanvasPanel.Canvas.Font.Color := clWhite;
        CanvasPanel.Canvas.TextOut(
          (GRID_WIDTH * CELL_SIZE div 2) - (CanvasPanel.Canvas.TextWidth('Premi R per ricominciare') div 2),
          (GRID_HEIGHT * CELL_SIZE div 2) + 10,
          'Premi R per ricominciare'
        );
      end;
  end;
end;

procedure TForm1.ShowMenu;
var
  i: Integer;
  TextWidth, TextHeight: Integer;
  MenuX, MenuY: Integer;
begin
  // Rimosso il rettangolo blu di test, ora disegniamo il menu vero
  CanvasPanel.Canvas.Brush.Color := clBlack; // Sfondo nero per il menu
  CanvasPanel.Canvas.FillRect(0, 0, CanvasPanel.Width, CanvasPanel.Height);

  // Disegna il titolo del gioco
  CanvasPanel.Canvas.Font.Assign(ScoreLabel.Font); // Per usare lo stesso font di ScoreLabel
  CanvasPanel.Canvas.Font.Size := 48;
  CanvasPanel.Canvas.Font.Color := clYellow;
  CanvasPanel.Canvas.TextOut(
    (CanvasPanel.Width div 2) - (CanvasPanel.Canvas.TextWidth('TETRIS') div 2),
    (CanvasPanel.Height div 2) - 150,
    'TETRIS'
  );

  CanvasPanel.Canvas.Font.Size := 24; // Dimensione del font per le opzioni
  MenuY := (CanvasPanel.Height div 2) - 50; // Posizione Y iniziale per le opzioni

  for i := Low(FMenuOptions) to High(FMenuOptions) do
  begin
    if i = FSelectedMenuOption then
      CanvasPanel.Canvas.Font.Color := clRed // Opzione selezionata in rosso
    else
      CanvasPanel.Canvas.Font.Color := clWhite; // Altre opzioni in bianco

    TextWidth := CanvasPanel.Canvas.TextWidth(FMenuOptions[i]);
    MenuX := (CanvasPanel.Width div 2) - (TextWidth div 2); // Centra il testo
    CanvasPanel.Canvas.TextOut(MenuX, MenuY, FMenuOptions[i]);
    Inc(MenuY, 40); // Sposta la prossima opzione più in basso
  end;
end;


procedure TForm1.GameTimerTimer(Sender: TObject);
begin
  // Il timer deve funzionare solo in modalità di gioco
  if FGameMode = gmPlaying then
    UpdateGame;
end;

procedure TForm1.CanvasPanelPaint(Sender: TObject);
begin
  DrawGame; // Richiama DrawGame per ridisegnare tutto
end;

end.
