import OpenEXR
import numpy as np
import array
import tensorflow as tf
from tensorflow.python.tools import freeze_graph as freezer
from helper.constants import get_width, get_height

IMG_WIDTH = get_width()
IMG_HEIGHT = get_height()

def freeze_graph(graph_structure_path, variable_checkpoint_path, frozen_graph_name):
    interactive_module = tf.load_op_library("C:/code/tensorflow/tensorflow/contrib/cmake/build/Release/interactive_ops.dll")
    freezer.freeze_graph(graph_structure_path, "",
                          False, variable_checkpoint_path, "InteractiveOutput",
                          "save/restore_all", "save/Const:0",
                          frozen_graph_name, True, "")


def write_output_file(filename, data):
    height = data.shape[0]
    width = data.shape[1]
    exr = OpenEXR.OutputFile(filename, OpenEXR.Header(width, height))
    output = array.array('f', [ 0.0 ] * (height * width))
    alpha = array.array('f', [ 1.0 ] * (height * width)).tostring()
    for y in range(height):
        for x in range(width):
            output[y * width + x] = data[y, x]
    output = output.tostring()
    exr.writePixels({'R': output, 'G': output, 'B': output, 'A': alpha})
    exr.close()

def write_output_array(filename, data):
    height = IMG_HEIGHT
    width = IMG_WIDTH
    output = array.array('f', data).tostring()
    alpha = array.array('f', [ 1.0 ] * (height * width)).tostring()
    exr = OpenEXR.OutputFile(filename, OpenEXR.Header(width, height))
    exr.writePixels({'R': output, 'G': output, 'B': output, 'A': alpha})
    exr.close()
