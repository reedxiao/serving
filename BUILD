package(
    default_visibility = ["//visibility:public"],
    features = [
        "-layering_check",
        "-parse_headers",
    ],
)

licenses(["notice"])  # Apache 2, BSD, MIT

cc_library(
    name = "SentencepieceOp",
    srcs = [
        "sentencepiece/tensorflow/sentencepiece_processor_ops.cc"
    ],
    hdrs = [
        "sentencepiece/src/sentencepiece_processor.h"
    ],
    strip_include_prefix = "sentencepiece/src/",
    alwayslink = 1,
    deps =
        [
            "@org_tensorflow//tensorflow/core:framework",
            "@org_tensorflow//tensorflow/core:lib",
            "@com_google_protobuf//:protobuf_headers",
            "@com_google_protobuf//:protobuf",
            ":sentencepiece"
        ]
)

cc_library(
    name = "sentencepiece",
    srcs = [
        "sentencepiece/build/src/libsentencepiece.a",
        "sentencepiece/build/src/libsentencepiece_train.a"
    ],
    hdrs = glob(
        ["sentencepiece/src/*.h"]
    ),
    deps = [
        "@com_google_protobuf//:protobuf_headers",
        "@com_google_protobuf//:protobuf",
    ],
    strip_include_prefix = "sentencepiece/src/"
)