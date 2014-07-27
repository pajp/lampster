#!/bin/sh -xe

#  install-gem-to-target.sh
#  Lampster
#
#  Created by Rasmus Sten on 2014-07-27.
#  Copyright (c) 2014 Rasmus Sten. All rights reserved.

export OUR_GEM_HOME="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/gems"
mkdir -p ${OUR_GEM_HOME}
if ! [ -d "${OUR_GEM_HOME}/gems/lifx"* ] ; then
    GEM_HOME="${OUR_GEM_HOME}" gem install lifx
else
    echo "LIFX gem already installed"
fi