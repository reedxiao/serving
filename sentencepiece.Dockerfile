FROM ubuntu:16.04 as base_build

ARG TF_SERVING_BRANCH=r1.15
ARG TF_SERVING_COMMIT=head

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    git \
    libcurl3-dev \
    libfreetype6-dev \
    libgoogle-perftools-dev \
    libpng-dev \
    libtool \
    libzmq3-dev \
    make \
    mlocate \
    openjdk-8-jdk\
    openjdk-8-jre-headless \
    pkg-config \
    python3-dev \
    software-properties-common \
    swig \
    unzip \
    wget \
    zip \
    zlib1g-dev \
    gdb \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ARG PROTOBUF_VERSION=3.7.0
RUN wget https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-cpp-${PROTOBUF_VERSION}.tar.gz \
  && tar -xzvf protobuf-cpp-${PROTOBUF_VERSION}.tar.gz \
  && cd protobuf-${PROTOBUF_VERSION} \
  && ./configure CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0" \
  && make -j "$(nproc)" \
  && make install \
  && ldconfig

RUN curl -fSsL -O https://bootstrap.pypa.io/get-pip.py \
  && python3 get-pip.py \
  && rm get-pip.py

RUN pip3 --no-cache-dir install \
  future>=0.17.1 \
  grpcio \
  h5py \
  keras_applications>=1.0.8 \
  keras_preprocessing>=1.1.0 \
  mock \
  numpy \
  requests

RUN set -ex \
  && ln -s /usr/bin/python3 usr/bin/python \
  && ln -s /usr/bin/pip3 /usr/bin/pip

ENV BAZEL_VERSION 0.24.1
WORKDIR /
RUN mkdir /bazel \
  && cd /bazel \
  && curl \
    -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36" \
    -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh \
  && curl \
    -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36" \
    -fSsL -o /bazel/LICENSE.txt https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE \
  && chmod +x bazel-*.sh \
  && ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh \
  && cd / \
  && rm -f /bazel/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh

WORKDIR /tensorflow-serving
RUN git clone --branch=${TF_SERVING_BRANCH} https://github.com/tensorflow/serving . \
  && git remote add upstream https://github.com/tensorflow/serving.git \
  && if [ "${TF_SERVING_COMMIT}" != "head" ]; then git checkout ${TF_SERVING_COMMIT} ; fi

FROM base_build as binary_build

# clone sentencepiece repo and build
RUN set -ex \
  && mkdir -p tensorflow_serving/custom_ops/sentencepiece_processor \
  && working_dir=`pwd` \
  && git clone https://github.com/google/sentencepiece.git tensorflow_serving/custom_ops/sentencepiece_processor/sentencepiece \
  && cd tensorflow_serving/custom_ops/sentencepiece_processor/sentencepiece \
  && mkdir build \
  && cd build \
  && cmake -DSPM_USE_BUILTIN_PROTOBUF=OFF -DSPM_ENABLE_TENSORFLOW_SHARED=ON .. \
  && make -j $(nproc) \
  && make install \
  && ldconfig

COPY BUILD ./BUILD
RUN cp BUILD tensorflow_serving/custom_ops/sentencepiece_processor/BUILD \
  && sed -i.bak '/@org_tensorflow\/\/tensorflow\/contrib:contrib_ops_op_lib/a\ "\/\/tensorflow_serving\/custom_ops\/sentencepiece_processor:sentencepiece_processor_ops",' \
       tensorflow_serving/model_servers/BUILD \
  && sed -i '/name = "tensorflow_model_server",/a\    linkopts = ["-Wl,--allow-multiple-definition", "-Wl,-rpath,/usr/lib"],' \
       tensorflow_serving/model_servers/BUILD

# Build, and install TensorFlow Serving
ARG BUILD_OPTIONS="--config=nativeopt"
ARG BAZEL_OPTIONS=""
# build bazel
RUN bazel build \
      --color=yes \
      --curses=yes \
      ${BAZEL_OPTIONS} \
      --verbose_failures \
      --output_filter=DONT_MATCH_ANYTHING \
      ${BUILD_OPTIONS} \
      tensorflow_serving/model_servers:tensorflow_model_server \
  && cp bazel-bin/tensorflow_serving/model_servers/tensorflow_model_server /usr/local/bin/

CMD ["/bin/bash"]