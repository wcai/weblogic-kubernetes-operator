#!/usr/bin/env bash
# Copyright 2017, 2018, Oracle Corporation and/or its affiliates.  All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

set -e

if [ ! $# -eq 1 ]; then
  echo "Syntax: ${BASH_SOURCE[0]} <subject alternative names, e.g. DNS:localhost,DNS:mymachine,DNS:mymachine.us.oracle.com,IP:127.0.0.1>"
  exit
fi

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CERT_DIR="${script_dir}/weblogic-operator-cert"

function cleanup {
  if [ $? -ne 0 ]; then
    echo "Failed to generate the weblogic operator certificate and private key."
    rm -rf ${CERT_DIR}
  fi
}

trap "cleanup" EXIT

SANS=$1
DAYS_VALID="3650"

TEMP_PW="temp_password"

OP_PREFIX="weblogic-operator"
OP_ALIAS="${OP_PREFIX}-alias"

OP_JKS="${CERT_DIR}/${OP_PREFIX}.jks"
OP_PKCS12="${CERT_DIR}/${OP_PREFIX}.p12"
OP_CSR="${CERT_DIR}/${OP_PREFIX}.csr"
OP_CERT_PEM="${CERT_DIR}/${OP_PREFIX}.cert.pem"
OP_KEY_PEM="${CERT_DIR}/${OP_PREFIX}.key.pem"

rm -rf ${CERT_DIR}
mkdir ${CERT_DIR}

# generate a keypair for the WebLogic Operator, putting it in a keystore
keytool \
  -genkey \
  -keystore ${OP_JKS} \
  -alias ${OP_ALIAS} \
  -storepass ${TEMP_PW} \
  -keypass ${TEMP_PW} \
  -keysize 2048 \
  -keyalg RSA \
  -validity ${DAYS_VALID} \
  -dname "CN=weblogic-operator" \
  -ext KU=digitalSignature,nonRepudiation,keyEncipherment,dataEncipherment,keyAgreement \
  -ext SAN="${SANS}"

# extract the operator cert to a pem file
keytool \
  -exportcert \
  -keystore ${OP_JKS} \
  -storepass ${TEMP_PW} \
  -alias ${OP_ALIAS} \
  -rfc \
  > ${OP_CERT_PEM}

# convert the operator keystore to a pkcs12 file
keytool \
  -importkeystore \
  -srckeystore ${OP_JKS} \
  -srcstorepass ${TEMP_PW} \
  -destkeystore ${OP_PKCS12} \
  -srcstorepass ${TEMP_PW} \
  -deststorepass ${TEMP_PW} \
  -deststoretype PKCS12

# extract the operator's key from the pkcs12 file to a pem file
openssl \
  pkcs12 \
  -in ${OP_PKCS12} \
  -passin pass:${TEMP_PW} \
  -nodes \
  -nocerts \
  -out ${OP_KEY_PEM}
