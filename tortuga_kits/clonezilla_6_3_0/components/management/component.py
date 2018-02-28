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

from logging import getLogger
import os
import tempfile
import shutil
import socket

from jinja2 import Template

from tortuga.exceptions import invalidActionRequest
from tortuga.kit.installer import ComponentInstallerBase
from tortuga.os_utility.osUtility import getOsObjectFactory
from tortuga.os_utility import tortugaSubprocess


logger = getLogger(__name__)


SRC_CLONEZILLA_LIVE_ZIP = '/tmp/clonezilla-live.zip'


class ComponentInstaller(ComponentInstallerBase):
    name = 'management'
    version = '6.3.0'
    os_list = [
        {'family': 'rhel', 'version': '7', 'arch': 'x86_64'},
    ]

    def action_post_install(self, *args, **kwargs):
        """
        Extract files from Clonezilla Live ZIP and install them

        """
        super().action_post_install(*args, **kwargs)
        os_obj_factory = getOsObjectFactory()
        tftp_dir = os.path.join(
            os_obj_factory.getOsBootHostManager().getTftproot(),
            'tortuga'
        )
        self.copy_clonezilla_files(tftp_dir)
        self.create_clonezilla_support_files(tftp_dir)

    def extract_clonezilla_files(self):
        """
        Extracts requisite files from Clonezilla Live zip archive

        Returns:
            <path to temporary directory containing files>

        Raises:
            InvalidActionRequest
            CommandFailed

        """
        if not os.path.exists(SRC_CLONEZILLA_LIVE_ZIP):
            raise invalidActionRequest.InvalidActionRequest(
                'Clonezilla Live zip archive not found: {}'.format(
                    SRC_CLONEZILLA_LIVE_ZIP))

        tmp_dir = tempfile.mkdtemp()

        logger.info(
            'Extracting Clonezilla Live ZIP to {}'.format(tmp_dir))

        reqd_files = [
            'live/vmlinuz',
            'live/initrd.img',
            'live/filesystem.squashfs'
        ]

        cmd = 'unzip -j -o {} -d {} {}'.format(
            SRC_CLONEZILLA_LIVE_ZIP, tmp_dir, ' '.join(reqd_files))

        tortugaSubprocess.executeCommand(cmd)

        return tmp_dir

    def copy_clonezilla_files(self, dst_dir):
        tmp_dir = self.extract_clonezilla_files()

        if not os.path.exists(dst_dir):
            logger.info(
                'Creating destination directory: {}'.format(dst_dir))
            os.makedirs(dst_dir)

        logger.info('Copying Clonezilla files to {}'.format(dst_dir))

        # Copy files into place
        file_pairs = [
            (
                os.path.join(tmp_dir, 'vmlinuz'),
                os.path.join(dst_dir, 'vmlinuz-cz')
            ),
            (
                os.path.join(tmp_dir, 'initrd.img'),
                os.path.join(dst_dir, 'initrd-cz.img')
            ),
            (
                os.path.join(tmp_dir, 'filesystem.squashfs'),
                os.path.join(dst_dir, 'filesystem.squashfs')
            )
        ]

        clonezilla_files_path = os.path.join(
            self.kit_installer.config_manager.getRoot(),
            'var/lib/clonezilla_files.txt'
        )
        with open(clonezilla_files_path, 'w') as fp:
            for tmp_src_file, tmp_dst_file in file_pairs:
                shutil.copyfile(tmp_src_file, tmp_dst_file)
                #
                # Add entry into file catalog for clean uninstallation later
                #
                fp.write(tmp_dst_file + '\n')
        #
        # Cleanup the temporary directory
        #
        tortugaSubprocess.executeCommand('rm -rf {}'.format(tmp_dir))

    def create_clonezilla_support_files(self, dst_dir):
        fqdn = socket.getfqdn()
        short_host_name = fqdn.split('.', 1)[0]

        ddict = {
            'cfmuser': self.kit_installer.config_manager.getCfmUser(),
            'cfmpasswd': self.kit_installer.config_manager.getCfmPassword(),
            'primary_installer': short_host_name,
            'puppet_master': fqdn,
            'wsurl': 'https://%s:%d/v1' % (
                short_host_name,
                self.kit_installer.config_manager.getAdminPort()
            ),
        }

        tmpl_file_path = os.path.join(self.kit_installer.files_path,
                                      'postrun.tmpl')
        with open(tmpl_file_path) as fp:
            tmpl = fp.read()
        postrun_file_path = os.path.join(dst_dir, 'czpostrun1')
        with open(postrun_file_path, 'w') as fp:
            fp.write(Template(tmpl).render(ddict))

        tmpl_file_path = os.path.join(self.kit_installer.files_path,
                                      'ocs.tmpl')
        with open(tmpl_file_path) as fp:
            tmpl = fp.read()
        ocs_file_path = os.path.join(dst_dir, 'clonezilla_custom_ocs')
        with open(ocs_file_path, 'w') as fp:
            fp.write(Template(tmpl).render(ddict))

        clonezilla_files_path = os.path.join(
            self.kit_installer.config_manager.getRoot(),
            'var/lib/clonezilla_files.txt'
        )
        with open(clonezilla_files_path, 'a') as fp:
            fp.write(postrun_file_path + '\n' + ocs_file_path + '\n')

    def cleanup(self):
        files_to_delete = []

        clonezilla_files_path = os.path.join(
            self.kit_installer.config_manager.getRoot(),
            'var/lib/clonezilla_files.txt'
        )
        if os.path.exists(clonezilla_files_path):
            with open(
                os.path.join(self.kit_installer.config_manager.getRoot(),
                             'lib/clonezilla_files.txt')) as fp:
                for line in fp.readlines():
                    files_to_delete.append(line.rstrip())

        for tmp_file_name in files_to_delete:
            tortugaSubprocess.executeCommand('rm -f {}'.format(tmp_file_name))

        tortugaSubprocess.executeCommand(
            'rm -f %s'.format(clonezilla_files_path))
