//*****************************************************************************
// Copyright 2020 Intel Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//*****************************************************************************
#pragma once

#include <string>

#include "tensorflow_serving/apis/prediction_service.grpc.pb.h"

#include "node.hpp"
#include "tensorinfo.hpp"

namespace ovms {

class ExitNode : public Node {
    tensorflow::serving::PredictResponse* response;

public:
    ExitNode(tensorflow::serving::PredictResponse* response) :
        Node("response"),
        response(response) {
    }

    // Exit node does not have execute logic.
    // It serializes its received input blobs to proto in ::fetchResults
    Status execute(ThreadSafeQueue<std::reference_wrapper<Node>>& notifyEndQueue) override {
        notifyEndQueue.push(*this);
        return StatusCode::OK;
    }

    Status fetchResults(BlobMap& outputs) override;

    // Exit nodes have no dependants
    void addDependant(Node& node) override {
        throw std::logic_error("This node cannot have dependant");
    }

    Status serialize(const InferenceEngine::Blob::Ptr& blob, tensorflow::TensorProto& proto);
};

}  // namespace ovms
