#
# Copyright (c) 2020 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import numpy as np


class AgeGender:
    name = "age_gender"
    dtype = np.float32
    input_name = "new_key"
    input_shape = (1, 3, 62, 62)
    output_name = ['age', 'gender']
    output_shape = {'age': (1, 1, 1, 1),
                    'gender': (1, 2, 1, 1)}
    rest_request_format = 'column_name'


class PVBDetectionV1:
    name = "pvb_detection"
    dtype = np.float32
    input_name = "data"
    input_shape = (1, 3, 300, 300)
    output_name = "detection_out"
    output_shape = (1, 1, 200, 7)
    rest_request_format = 'column_name'


class FaceDetection(PVBDetectionV1):
    name = "face_detection"


class PVBDetectionV2(PVBDetectionV1):
    input_shape = (1, 3, 1024, 1024)


PVBDetection = [PVBDetectionV1, PVBDetectionV2]


class Resnet:
    name = "resnet"
    dtype = np.float32
    input_name = "map/TensorArrayStack/TensorArrayGatherV3"
    input_shape = (1, 3, 224, 224)
    output_name = "softmax_tensor"
    output_shape = (1, 1001)
    rest_request_format = 'column_name'
    model_path = "/opt/ml/resnet_V1_50"


class ResnetBS4:
    name = "resnet_bs4"
    dtype = np.float32
    input_name = "map/TensorArrayStack/TensorArrayGatherV3"
    input_shape = (4, 3, 224, 224)
    output_name = "softmax_tensor"
    output_shape = (4, 1001)
    rest_request_format = 'row_noname'


class ResnetBS8:
    name = "resnet_bs8"
    dtype = np.float32
    input_name = "map/TensorArrayStack/TensorArrayGatherV3"
    input_shape = (8, 3, 224, 224)
    output_name = "softmax_tensor"
    output_shape = (8, 1001)
    rest_request_format = 'row_noname'
    model_path = "/opt/ml/resnet_V1_50_batch8"


class ResnetS3:
    name = "resnet_s3"
    dtype = np.float32
    input_name = "map/TensorArrayStack/TensorArrayGatherV3"
    input_shape = (1, 3, 224, 224)
    output_name = "softmax_tensor"
    output_shape = (1, 1001)
    rest_request_format = 'row_name'


class ResnetGS:
    name = "resnet_gs"
    dtype = np.float32
    input_name = "input"
    input_shape = (1, 3, 224, 224)
    output_name = "resnet_v1_50/predictions/Reshape_1"
    output_shape = (1, 1000)
    rest_request_format = 'row_name'