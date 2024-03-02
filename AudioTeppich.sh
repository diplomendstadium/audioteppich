#!/bin/bash

# AudioTeppich Version 1.1
# CC BY-NC-SA 4.0 Deed
# https://github.com/diplomendstadium/audioteppich
# Podcastlinks von: https://fyyd.de/

# Stellen Sie sicher, dass die notwendigen Ordner existieren
mkdir -p 1_rohdaten 2_snippets 3_mixfiles

# Download der Rohdaten
#!/bin/bash

# Erstellt den Zielordner, falls nicht vorhanden
mkdir -p 1_rohdaten

# Liest jede Zeile in rohdaten.list
while IFS= read -r line; do
  # Extrahiert den Dateinamen aus der URL
  filename=$(basename "$line")
  
  # Überprüft, ob die Datei bereits im Zielordner existiert
  if [ -f "1_rohdaten/$filename" ]; then
    echo "Die Datei $filename existiert bereits, überspringe den Download."
  else
    echo "Versuche, $line herunterzuladen..."
    
    # Versucht, die Datei herunterzuladen und speichert sie im Ordner 1_rohdaten
    wget --show-progress -q "$line" -P 1_rohdaten 
    
    # Prüft, ob der Download erfolgreich war
    if [ $? -ne 0 ]; then
      echo "Fehler: Konnte $line nicht herunterladen."
    else
      echo "$line erfolgreich heruntergeladen."
    fi
  fi
  
done < "rohdaten.list"

echo "Alle Downloads abgeschlossen."

# Wir machen aus den Rohdaten lustige kurze Snippets
# Definiert den Eingangs- und Ausgangsordner
inputDir="1_rohdaten"
outputDir="2_snippets"

# Zählt die Anzahl der Dateien im Eingangsordner
totalFiles=$(find "$inputDir" -type f | wc -l)
currentFile=0

echo "Starte die Erstellung von Snippets..."

# Durchläuft alle Dateien im Eingangsordner
for file in "$inputDir"/*; do
  ((currentFile++))
  basename=$(basename "$file")
  
  echo "Verarbeite Datei $currentFile von $totalFiles: $basename"

  startTime=0
  snippetDuration=180
  fileDuration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
  neededSnippets=$(echo "$fileDuration / $snippetDuration" | bc)

  for ((i=0; i<$neededSnippets; i++)); do
    randomName=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 8)
    
    ffmpeg -nostdin -loglevel error -ss "$startTime" -t "$snippetDuration" -i "$file" -acodec libmp3lame -ar 44100 -ab 128k "$outputDir/$randomName.mp3"
    
    if [ $? -eq 0 ]; then
      echo "Snippet $((i+1)) von $neededSnippets für $basename erstellt."
    else
      echo "Fehler beim Erstellen von Snippet $((i+1)) für $basename."
      break
    fi
    
    startTime=$((startTime + snippetDuration))
  done
done

echo "Alle Snippets wurden erfolgreich erstellt."

# Jetzt erstellen wir unsere Mixfiles 
# Definiert den Eingangs- und Ausgangsordner
inputDir="2_snippets"
outputDir="3_mixfiles"

# Anzahl der Durchläufe
runs=500

for ((i=1; i<=runs; i++)); do
    # Generiert einen zufälligen Dateinamen für die Ausgabedatei
    outputName=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 8).mp3
    
    # Wählt zufällig 5 Audiodateien aus
    files=($(shuf -n5 -e $inputDir/*))
    
    # Erstellt den Befehlsteil für die Eingabedateien
    inputs=""
    for file in "${files[@]}"; do
        inputs+="-i $file "
    done

    # Generiert eine zufällige Dauer zwischen 10 Sekunden (min) und 180 Sekunden (max)
    duration=$((RANDOM % 171 + 10))

    # Führt den Mischvorgang mit ffmpeg durch
    ffmpeg -loglevel error $inputs -filter_complex "amix=inputs=${#files[@]}:duration=first:dropout_transition=3,volume=2" -t $duration "$outputDir/$outputName"
    
    echo "Mix $i erstellt: $outputName"
done

echo "Alle $runs Mixe wurden erstellt."

# Jetzt packen wir alles in eine Ergebnisdatei und räumen auf
# Definiert den Ordner, aus dem die Audiodateien gelesen werden sollen
inputDir="3_mixfiles"

# Erstellt den Namen der Ausgabedatei basierend auf dem aktuellen Zeitstempel
outputFile="$(date +%Y%m%d%H%M%S)_AudioTeppich.mp3"

# Fügt alle Audiodateien im angegebenen Ordner zusammen
for file in "$inputDir"/*; do
  echo "file '$file'" >> concat.txt
done

# Verwendet ffmpeg, um die Audiodateien zusammenzufassen und in eine einzige Datei mit 128kbps zu konvertieren
ffmpeg -f concat -safe 0 -i concat.txt -c:a libmp3lame -b:a 128k "$outputFile"

# Löscht die temporäre Dateiliste
rm concat.txt

# Löscht die Ordner "2_snippets" und "3_mixfiles", falls gewünscht
rm -r "2_snippets" "3_mixfiles"

echo "Der Vorgang wurde abgeschlossen. Die finale Audiodatei ist: $outputFile"
