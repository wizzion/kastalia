import csv
import pytesseract
import sys
from io import StringIO
from PIL import Image

img = Image.open(sys.argv[1])
data = pytesseract.image_to_data(img,lang='deu')
json=""

with StringIO(data) as csv_file:
    csv_reader = csv.DictReader(csv_file,delimiter='\t')
    line_count = 0
    for row in csv_reader:
        text=row['text'].replace('\\','\\\\')
        text=text.replace('"','\\"')
        json=json+('{"id":w_KNOTID_'+str(line_count)+'","ocr":"'+text+'","left":'+str(row['left'])+',"top":'+str(row['top'])+',"width":'+str(row['width'])+',"height":'+str(row['height'])+'},')
        line_count += 1
print(json)
