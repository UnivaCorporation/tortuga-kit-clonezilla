# Copyright 2008-2018 Univa Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


class tortuga_kit_clonezilla::manager::packages {
  require tortuga::packages

  ensure_resource('package', 'unzip', {'ensure' => 'installed'})
}

class tortuga_kit_clonezilla::manager::config {
  tortuga::run_post_install { 'manager_post_install':
    kitdescr  => $tortuga_kit_clonezilla::config::kitdescr,
    compdescr => $tortuga_kit_clonezilla::manager::compdescr,
  }
}

class tortuga_kit_clonezilla::manager {
  contain tortuga_kit_clonezilla::manager::packages
  contain tortuga_kit_clonezilla::manager::config

  $compdescr = "manager-${tortuga_kit_clonezilla::config::major_version}"
}
