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

VIRTUALENV_EXE := python3 -m virtualenv -p python3
VIRTUALENV_DIR := .venv
ACTIVATE="$(VIRTUALENV_DIR)/bin/activate"
STYLE_CHECK_OPTS := --extensions=hpp,cc,cpp,h \
	--output=vs7 \
	--recursive \
	--linelength=120 \
	--filter=-build/c++11,-runtime/references,-whitespace/indent,-build/include_order,-runtime/indentation_namespace,-build/namespaces,-whitespace/line_length,-runtime/string,-readability/casting,-runtime/explicit,-readability/todo
STYLE_CHECK_DIRS := src
HTTP_PROXY := "$(http_proxy)"
HTTPS_PROXY := "$(https_proxy)"
NO_PROXY := "$(no_proxy)"

# Image on which OVMS is compiled. If DIST_OS is not set, it's also used for a release image.
# Currently supported BASE_OS values are: ubuntu centos clearlinux
BASE_OS ?= centos

# do not change this; change versions per OS a few lines below (BASE_OS_TAG_*)!
BASE_OS_TAG ?= latest

BASE_OS_TAG_UBUNTU ?= 18.04
BASE_OS_TAG_CENTOS ?= 8
BASE_OS_TAG_CLEARLINUX ?= latest
HAS_AVX := $(shell grep avx /proc/cpuinfo | wc -l)

check:
ifeq ($(HAS_AVX),0)
	@echo "CPU with AVX support required"
	exit 1
endif
	@echo "CPU with AVX support detected"
OV_SOURCE_BRANCH ?= 2020.3.0

ifeq ($(BASE_OS),ubuntu)
  BASE_OS_TAG=$(BASE_OS_TAG_UBUNTU)
endif
ifeq ($(BASE_OS),centos)
  BASE_OS_TAG=$(BASE_OS_TAG_CENTOS)
endif
ifeq ($(BASE_OS),clearlinux)
  BASE_OS_TAG=$(BASE_OS_TAG_CLEARLINUX)
endif

# Option to Override release image.
# Release image OS *must have* glibc version >= glibc version on BASE_OS:
DIST_OS ?= $(BASE_OS)
DIST_OS_TAG ?= $(BASE_OS_TAG)

OVMS_CPP_DOCKER_IMAGE ?= ovms
OVMS_CPP_IMAGE_TAG ?= latest

OVMS_CPP_CONTAINTER_NAME ?= server-test
OVMS_CPP_CONTAINTER_PORT ?= 9178

TEST_PATH ?= tests/functional/

.PHONY: default docker_build \

default: docker_build

venv:check $(ACTIVATE)
	@echo -n "Using venv "
	@. $(ACTIVATE); python3 --version

$(ACTIVATE):
	@echo "Updating virtualenv dependencies in: $(VIRTUALENV_DIR)..."
	@test -d $(VIRTUALENV_DIR) || $(VIRTUALENV_EXE) $(VIRTUALENV_DIR)
	@. $(ACTIVATE); pip$(PY_VERSION) install --upgrade pip
	@. $(ACTIVATE); pip$(PY_VERSION) install -vUqq setuptools
	@. $(ACTIVATE); pip$(PY_VERSION) install -qq -r tests/requirements.txt
	@touch $(ACTIVATE)

style: venv
	@echo "Style-checking codebase..."
	@. $(ACTIVATE); echo ${PWD}; cpplint ${STYLE_CHECK_OPTS} ${STYLE_CHECK_DIRS}

.PHONY: docker_build
docker_build:
	@echo "Building docker image $(BASE_OS)"
	# Provide metadata information into image if defined
	@mkdir -p .workspace
ifeq ($(NO_DOCKER_CACHE),true)
	$(eval NO_CACHE_OPTION:=--no-cache)
	@echo "Docker image will be rebuilt from scratch"
endif
ifneq ($(OVMS_METADATA_FILE),)
	@cp $(OVMS_METADATA_FILE) .workspace/metadata.json
else
	@touch .workspace/metadata.json
endif
	@cat .workspace/metadata.json
	docker build $(NO_CACHE_OPTION) -f Dockerfile.$(BASE_OS) . \
		--build-arg http_proxy=$(HTTP_PROXY) --build-arg https_proxy="$(HTTPS_PROXY)" \
		--build-arg ovms_metadata_file=.workspace/metadata.json --build-arg ov_source_branch="$(OV_SOURCE_BRANCH)" \
		-t $(OVMS_CPP_DOCKER_IMAGE)-build:$(OVMS_CPP_IMAGE_TAG)
	docker build $(NO_CACHE_OPTION) -f DockerfileMakePackage . \
		--build-arg http_proxy=$(HTTP_PROXY) --build-arg https_proxy="$(HTTPS_PROXY)" \
		-t $(OVMS_CPP_DOCKER_IMAGE)-pkg:$(OVMS_CPP_IMAGE_TAG) \
		--build-arg BUILD_IMAGE=$(OVMS_CPP_DOCKER_IMAGE)-build:$(OVMS_CPP_IMAGE_TAG)
	docker build $(NO_CACHE_OPTION) -f DockerfileRelease . \
		--build-arg http_proxy=$(HTTP_PROXY) --build-arg https_proxy="$(HTTPS_PROXY)" \
		-t $(OVMS_CPP_DOCKER_IMAGE):$(OVMS_CPP_IMAGE_TAG) \
		--build-arg PKG_IMAGE=$(OVMS_CPP_DOCKER_IMAGE)-pkg:$(OVMS_CPP_IMAGE_TAG) \
		--build-arg DIST_IMAGE=$(DIST_OS):$(DIST_OS_TAG)
	rm -vrf dist/$(DIST_OS) && mkdir -vp dist/$(DIST_OS) && cd dist/$(DIST_OS) && \
		docker run $(OVMS_CPP_DOCKER_IMAGE)-pkg:$(OVMS_CPP_IMAGE_TAG) bash -c \
			"tar -c -C / ovms.tar.gz* ; sleep 2" | tar -x
	cd dist/$(DIST_OS) && sha256sum --check ovms.tar.gz.sha256

test_perf: venv
	@echo "Dropping test container if exist"
	@docker rm --force $(OVMS_CPP_CONTAINTER_NAME) || true
	@echo "Starting docker image"
	@./tests/performance/download_model.sh
	@docker run -d --name $(OVMS_CPP_CONTAINTER_NAME) \
		-v $(HOME)/resnet50:/models/resnet50 \
		-p $(OVMS_CPP_CONTAINTER_PORT):$(OVMS_CPP_CONTAINTER_PORT) \
		$(OVMS_CPP_DOCKER_IMAGE):$(OVMS_CPP_IMAGE_TAG) \
		--model_name resnet --model_path /models/resnet50 --port $(OVMS_CPP_CONTAINTER_PORT); sleep 5
	@echo "Running latency test"
	@. $(ACTIVATE); python3 tests/performance/grpc_latency.py \
		--images_numpy_path tests/performance/imgs.npy \
		--labels_numpy_path tests/performance/labels.npy \
		--iteration 1000 \
		--batchsize 1 \
		--report_every 100 \
		--input_name data
	@echo "Removing test container"
	@docker rm --force $(OVMS_CPP_CONTAINTER_NAME)

test_throughput: venv
	@echo "Dropping test container if exist"
	@docker rm --force $(OVMS_CPP_CONTAINTER_NAME) || true
	@echo "Starting docker image"
	@./tests/performance/download_model.sh
	@docker run -d --name $(OVMS_CPP_CONTAINTER_NAME) \
		-v $(HOME)/resnet50:/models/resnet50 \
		-p $(OVMS_CPP_CONTAINTER_PORT):$(OVMS_CPP_CONTAINTER_PORT) \
		$(OVMS_CPP_DOCKER_IMAGE):$(OVMS_CPP_IMAGE_TAG) \
		--model_name resnet \
		--model_path /models/resnet50 \
		--port $(OVMS_CPP_CONTAINTER_PORT); \
		sleep 5
	@echo "Running throughput test"
	@. $(ACTIVATE); cd tests/performance; ./grpc_throughput.sh 28 \
		--images_numpy_path imgs.npy \
		--labels_numpy_path labels.npy \
		--iteration 500 \
		--batchsize 1 \
		--input_name data
	@echo "Removing test container"
	@docker rm --force $(OVMS_CPP_CONTAINTER_NAME)

test_functional: venv
	@. $(ACTIVATE); pytest --json=report.json -v -s $(TEST_PATH)

