from helper.load_data import read_input_data, read_truth_data, read_input_file, read_truth_file
from helper.save_data import write_output_file, write_output_array, write_output_array2
import os

def convert_folder(foldername):
    files = os.listdir(foldername)
    count = 0
    maxcount = len(files)
    for entry in files:
        filename = foldername + entry
        if "groundtruth" in entry:
            T = read_truth_file(filename)
            write_output_array(filename, T)
        if "input" in entry:
            R,G,B,D = read_input_file(filename)
            write_output_array2(filename, R, G, B, D)
        count += 1
        if count % 100 == 0:
            mystring = "Done with Image " + str(count) + " from " + str(maxcount) + " in folder: " + foldername
            output = mystring.encode("utf-8").decode("ascii")
            print(output)

def load_models(modellocation):
    models = []
    with open(modellocation) as f:
        for line in f:
            if line.endswith("\n"):
                line = line[:-1]
            models.append(line)
    return models

############################

modellocation = "verify_models.txt"
datalocation = "D:/train_data/"

modellist = load_models(modellocation)
print(modellist)
for model in modellist:
    print("Converting " + model)
    foldername = datalocation + model + "/"
    convert_folder(foldername)
