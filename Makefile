#
# MIT License
#
# (C) Copyright 2022-2023 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
SHELL := /bin/bash

ifeq ($(NAME),)
export NAME := $(shell basename $(shell pwd))
endif

ifeq ($(ARCH),)
export ARCH := x86_64
endif

ifeq ($(VERSION),)
export VERSION := $(shell git describe --tags | tr -s '-' '~' | tr -d '^v')
endif

ROOTDIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

SPEC_NAME ?= ${NAME}
SPEC_FILE ?= ${SPEC_NAME}.spec
BUILD_DIR ?= $(CURDIR)/build
SOURCE_NAME ?= ${SPEC_NAME}-${VERSION}
SOURCE_PATH := ${BUILD_DIR}/SOURCES/${SOURCE_NAME}.tar.bz2

.PHONY: rpm clean

rpm: rpm_package_source rpm_build

prepare:
	$(RM) -rf $(BUILD_DIR)
	mkdir -p "$(BUILD_DIR)/SPECS" 
	mkdir -p "$(BUILD_DIR)/SOURCES"
	cp $(SPEC_FILE) $(BUILD_DIR)/SPECS/
	cp -r systemd/* $(BUILD_DIR)/SOURCES/
	cp -r grafana/* $(BUILD_DIR)/SOURCES/

rpm_package_source:
	tar --transform 'flags=r;s,^,/$(SOURCE_NAME)/,' --exclude .git --exclude dist -cvjf $(SOURCE_PATH) .

clean:
	$(RM) -rf $(BUILD_DIR)

rpm_build: pit-observability.spec systemd/prometheus.service systemd/grok-exporter.service systemd/grafana.service systemd/prometheus.sh systemd/grafana.sh systemd/grok-exporter.sh systemd/config.yml grafana/csm-install-progress.json grafana/device-error.json grafana/dhcp-error.json grafana/pxe-error.json grafana/known-issues-message-frequency.json grafana/datasource.yml grafana/dashboard.yml grafana/pit-goss-test.json
	rpmbuild --nodeps \
		--define "_topdir $(BUILD_DIR)" \
	    --define "_sourcedir $(BUILD_DIR)/SOURCES" \
        -ba $(SPEC_FILE)
