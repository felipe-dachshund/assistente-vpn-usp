#!/usr/bin/env python3
"""
Testes automatizados para assistente-vpn-usp.sh
Utiliza unittest da biblioteca padrão de Python (sem dependências externas).
"""

import os
import subprocess
import tempfile
import unittest

SCRIPT_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assistente-vpn-usp.sh"))


class BaseScriptTestCase(unittest.TestCase):
    def run_script(self, args, env=None, check=False):
        full_env = os.environ.copy()
        if env:
            full_env.update(env)
        cmd = [SCRIPT_PATH] + args
        proc = subprocess.run(
            cmd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=full_env,
        )
        if check and proc.returncode != 0:
            raise subprocess.CalledProcessError(proc.returncode, cmd, proc.stdout, proc.stderr)
        return proc


class TestCLIHelpAndVersion(BaseScriptTestCase):
    def test_help_flag_short(self):
        res = self.run_script(["-h"])
        self.assertEqual(res.returncode, 0)
        self.assertIn("Uso:", res.stdout)
        self.assertIn("install", res.stdout)
        self.assertIn("remove", res.stdout)

    def test_help_flag_long(self):
        res = self.run_script(["--help"])
        self.assertEqual(res.returncode, 0)
        self.assertIn("Uso:", res.stdout)

    def test_help_action(self):
        res = self.run_script(["help"])
        self.assertEqual(res.returncode, 0)
        self.assertIn("Uso:", res.stdout)

    def test_version_flag_short(self):
        res = self.run_script(["-v"])
        self.assertEqual(res.returncode, 0)
        self.assertTrue(res.stdout.strip().replace(".", "").isdigit())

    def test_version_flag_long(self):
        res = self.run_script(["--version"])
        self.assertEqual(res.returncode, 0)
        self.assertTrue(res.stdout.strip().replace(".", "").isdigit())

    def test_version_action(self):
        res = self.run_script(["version"])
        self.assertEqual(res.returncode, 0)
        self.assertTrue(res.stdout.strip().replace(".", "").isdigit())

    def test_no_arguments(self):
        res = self.run_script([])
        self.assertEqual(res.returncode, 1)
        self.assertIn("Uso:", res.stdout)

    def test_invalid_option(self):
        res = self.run_script(["--opcao-invalida", "install"])
        self.assertEqual(res.returncode, 1)
        self.assertIn("Uso:", res.stdout + res.stderr)

    def test_unknown_action(self):
        res = self.run_script(["acao-desconhecida"])
        self.assertEqual(res.returncode, 1)
        self.assertIn("Ação desconhecida", res.stderr)

    def test_multiple_actions(self):
        res = self.run_script(["install", "remove"])
        self.assertEqual(res.returncode, 1)
        self.assertIn("Apenas uma ação pode ser especificada", res.stderr)

    def test_root_required_without_dry_run(self):
        # Quando executado por usuário não-root sem --dry-run
        if os.geteuid() != 0:
            res = self.run_script(["install"])
            self.assertEqual(res.returncode, 2)
            self.assertIn("privilégios de superusuário", res.stderr)


class TestNUSPValidation(BaseScriptTestCase):
    def test_valid_nusp(self):
        res = self.run_script(["--dry-run", "--nusp=12345678", "install"])
        self.assertEqual(res.returncode, 0)

    def test_formatted_nusp(self):
        # NUSP com pontos, traços ou espaços deve ser aceito e sanitizado
        res = self.run_script(["--dry-run", "--nusp=12.345.678", "install"])
        self.assertEqual(res.returncode, 0)

    def test_invalid_nusp_letters(self):
        res = self.run_script(["--dry-run", "--nusp=abc1234", "install"])
        self.assertEqual(res.returncode, 1)
        self.assertIn("Número USP inválido", res.stderr)


class TestDesktopEnvironmentDetection(BaseScriptTestCase):
    """
    Verifica se ambientes que utilizam GTK4 (GNOME, Xfce, MATE, Cinnamon, LXDE,
    COSMIC etc.) incluem o pacote de integração gráfica
    'network-manager-openconnect-gnome', enquanto o KDE Plasma instala apenas
    o pacote base.
    """

    def test_gnome_desktop(self):
        res = self.run_script(["--dry-run", "install"], env={"XDG_CURRENT_DESKTOP": "GNOME"})
        self.assertEqual(res.returncode, 0)
        self.assertIn("interface GTK detectado", res.stderr)
        self.assertIn("network-manager-openconnect-gnome", res.stderr)

    def test_ubuntu_gnome_desktop(self):
        res = self.run_script(["--dry-run", "install"], env={"XDG_CURRENT_DESKTOP": "ubuntu:GNOME"})
        self.assertEqual(res.returncode, 0)
        self.assertIn("network-manager-openconnect-gnome", res.stderr)

    def test_xfce_desktop(self):
        res = self.run_script(["--dry-run", "install"], env={"XDG_CURRENT_DESKTOP": "XFCE"})
        self.assertEqual(res.returncode, 0)
        self.assertIn("interface GTK detectado", res.stderr)
        self.assertIn("network-manager-openconnect-gnome", res.stderr)

    def test_mate_desktop(self):
        res = self.run_script(["--dry-run", "install"], env={"XDG_CURRENT_DESKTOP": "MATE"})
        self.assertEqual(res.returncode, 0)
        self.assertIn("interface GTK detectado", res.stderr)
        self.assertIn("network-manager-openconnect-gnome", res.stderr)

    def test_cinnamon_desktop(self):
        res = self.run_script(["--dry-run", "install"], env={"XDG_CURRENT_DESKTOP": "X-Cinnamon"})
        self.assertEqual(res.returncode, 0)
        self.assertIn("interface GTK detectado", res.stderr)
        self.assertIn("network-manager-openconnect-gnome", res.stderr)

    def test_lxde_desktop(self):
        res = self.run_script(["--dry-run", "install"], env={"XDG_CURRENT_DESKTOP": "LXDE"})
        self.assertEqual(res.returncode, 0)
        self.assertIn("interface GTK detectado", res.stderr)
        self.assertIn("network-manager-openconnect-gnome", res.stderr)

    def test_cosmic_desktop(self):
        res = self.run_script(["--dry-run", "install"], env={"XDG_CURRENT_DESKTOP": "COSMIC"})
        self.assertEqual(res.returncode, 0)
        self.assertIn("interface GTK detectado", res.stderr)
        self.assertIn("network-manager-openconnect-gnome", res.stderr)

    def test_kde_plasma_desktop(self):
        res = self.run_script(["--dry-run", "install"], env={"XDG_CURRENT_DESKTOP": "KDE"})
        self.assertEqual(res.returncode, 0)
        self.assertIn("Ambiente de trabalho KDE detectado", res.stderr)
        # O KDE Plasma NÃO deve instalar network-manager-openconnect-gnome
        output_packages = [line for line in res.stderr.splitlines() if "Pacote(s) a ser(em) instalado(s):" in line]
        self.assertTrue(len(output_packages) > 0)
        self.assertNotIn("network-manager-openconnect-gnome", output_packages[0])
        self.assertIn("network-manager-openconnect", output_packages[0])

    def test_headless_cli_environment(self):
        res = self.run_script(["--dry-run", "install"], env={"XDG_CURRENT_DESKTOP": "none"})
        self.assertEqual(res.returncode, 0)
        self.assertIn("Ambiente gráfico não detectado", res.stderr)
        output_packages = [line for line in res.stderr.splitlines() if "Pacote(s) a ser(em) instalado(s):" in line]
        self.assertTrue(len(output_packages) > 0)
        self.assertNotIn("network-manager-openconnect-gnome", output_packages[0])
        self.assertIn("network-manager-openconnect", output_packages[0])


class TestDistributionDetection(BaseScriptTestCase):
    """
    Testa o comportamento de detecção de distribuição e versão do Linux
    através da variável OS_RELEASE_FILE simulada.
    """

    def test_debian_12_bookworm_defaults_to_openfortigui(self):
        with tempfile.NamedTemporaryFile("w", delete=False) as f:
            f.write('ID=debian\nNAME="Debian GNU/Linux"\nVERSION_ID="12"\n')
            temp_path = f.name
        try:
            res = self.run_script(
                ["--dry-run", "install"],
                env={"OS_RELEASE_FILE": temp_path, "XDG_CURRENT_DESKTOP": "none"},
            )
            self.assertEqual(res.returncode, 0)
            self.assertIn("OpenFortiGUI", res.stderr)
        finally:
            os.remove(temp_path)

    def test_debian_12_with_openfortivpn_flag(self):
        with tempfile.NamedTemporaryFile("w", delete=False) as f:
            f.write('ID=debian\nNAME="Debian GNU/Linux"\nVERSION_ID="12"\n')
            temp_path = f.name
        try:
            res = self.run_script(
                ["--dry-run", "--openfortivpn", "--nusp=12345678", "install"],
                env={"OS_RELEASE_FILE": temp_path, "XDG_CURRENT_DESKTOP": "none"},
            )
            self.assertEqual(res.returncode, 0)
            self.assertIn("OpenFortiVPN", res.stderr)
        finally:
            os.remove(temp_path)

    def test_debian_13_trixie_defaults_to_openconnect(self):
        with tempfile.NamedTemporaryFile("w", delete=False) as f:
            f.write('ID=debian\nNAME="Debian GNU/Linux"\nVERSION_ID="13"\n')
            temp_path = f.name
        try:
            res = self.run_script(
                ["--dry-run", "install"],
                env={"OS_RELEASE_FILE": temp_path, "XDG_CURRENT_DESKTOP": "none"},
            )
            self.assertEqual(res.returncode, 0)
            self.assertIn("OpenConnect", res.stderr)
        finally:
            os.remove(temp_path)

    def test_debian_testing_unstable_no_version_id_defaults_to_openconnect(self):
        with tempfile.NamedTemporaryFile("w", delete=False) as f:
            f.write('ID=debian\nNAME="Debian GNU/Linux"\n')
            temp_path = f.name
        try:
            res = self.run_script(
                ["--dry-run", "install"],
                env={"OS_RELEASE_FILE": temp_path, "XDG_CURRENT_DESKTOP": "none"},
            )
            self.assertEqual(res.returncode, 0)
            self.assertIn("OpenConnect", res.stderr)
        finally:
            os.remove(temp_path)

    def test_ubuntu_24_defaults_to_openconnect(self):
        with tempfile.NamedTemporaryFile("w", delete=False) as f:
            f.write('ID=ubuntu\nID_LIKE=debian\nNAME="Ubuntu"\nVERSION_ID="24.04"\n')
            temp_path = f.name
        try:
            res = self.run_script(
                ["--dry-run", "install"],
                env={"OS_RELEASE_FILE": temp_path, "XDG_CURRENT_DESKTOP": "none"},
            )
            self.assertEqual(res.returncode, 0)
            self.assertIn("OpenConnect", res.stderr)
        finally:
            os.remove(temp_path)


class TestDryRunRemove(BaseScriptTestCase):
    def test_remove_dry_run(self):
        res = self.run_script(["--dry-run", "remove"])
        self.assertEqual(res.returncode, 0)
        self.assertIn("Iniciando a remoção completa do FortiClient", res.stderr)
        self.assertIn("Remoção de arquivos de sistema do FortiClient concluída!", res.stdout + res.stderr)


if __name__ == "__main__":
    unittest.main()
