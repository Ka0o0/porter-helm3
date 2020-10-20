package helm3

import (
	"fmt"
	"os/exec"
	"sort"
	"strings"

	"github.com/pkg/errors"
	yaml "gopkg.in/yaml.v2"
)

type InstallAction struct {
	Steps []InstallStep `yaml:"install"`
}

type InstallStep struct {
	InstallArguments `yaml:"helm3"`
}

type InstallArguments struct {
	Step `yaml:",inline"`

	Namespace string            `yaml:"namespace"`
	Name      string            `yaml:"name"`
	Chart     string            `yaml:"chart"`
	Version   string            `yaml:"version"`
	Replace   bool              `yaml:"replace"`
	Set       map[string]string `yaml:"set"`
	Values    []string          `yaml:"values"`
	Devel     bool              `yaml:"devel`
	UpSert    bool              `yaml:"devel`
	Wait      bool              `yaml:"wait"`
}

func (m *Mixin) Install() error {

	payload, err := m.getPayloadData()
	if err != nil {
		return err
	}

	kubeClient, err := m.getKubernetesClient("/root/.kube/config")
	if err != nil {
		return errors.Wrap(err, "couldn't get kubernetes client")
	}

	var action InstallAction
	err = yaml.Unmarshal(payload, &action)
	if err != nil {
		return err
	}
	if len(action.Steps) != 1 {
		return errors.Errorf("expected a single step, but got %d", len(action.Steps))
	}
	step := action.Steps[0]

	cmd := m.NewCommand("helm3")

	if step.UpSert {
		cmd.Args = append(cmd.Args, "upgrade", "--install", step.Name, step.Chart)

	} else {
		cmd.Args = append(cmd.Args, "install", step.Name, step.Chart)
	}

	if step.Namespace != "" {
		cmd.Args = append(cmd.Args, "--namespace", step.Namespace)
	}

	if step.Version != "" {
		cmd.Args = append(cmd.Args, "--version", step.Version)
	}

	if step.Replace {
		cmd.Args = append(cmd.Args, "--replace")
	}

	if step.Wait {
		cmd.Args = append(cmd.Args, "--wait")
	}

	if step.Devel {
		cmd.Args = append(cmd.Args, "--devel")
	}

	for _, v := range step.Values {
		cmd.Args = append(cmd.Args, "--values", v)
	}

	cmd.Args = HandleSettingChartValuesForInstall(step, cmd)

	cmd.Stdout = m.Out
	cmd.Stderr = m.Err

	// format the command with all arguments
	prettyCmd := fmt.Sprintf("%s %s", cmd.Path, strings.Join(cmd.Args, " "))
	fmt.Fprintln(m.Out, prettyCmd)

	// Here where really the command get executed
	err = cmd.Start()
	// Exit on error
	if err != nil {
		return fmt.Errorf("could not execute command, %s: %s", prettyCmd, err)
	}
	err = cmd.Wait()
	// Exit on error
	if err != nil {
		return err
	}
	err = m.handleOutputs(kubeClient, step.Namespace, step.Outputs)
	return err
}

// Prepare set arguments
func HandleSettingChartValuesForInstall(step InstallStep, cmd *exec.Cmd) []string {
	// sort the set consistently
	setKeys := make([]string, 0, len(step.Set))
	for k := range step.Set {

		setKeys = append(setKeys, k)
	}
	sort.Strings(setKeys)

	for _, k := range setKeys {
		//Hack unitl helm introduce `--set-literal` for complex keys
		// see https://github.com/helm/helm/issues/4030
		// TODO : Fix this later upon `--set-literal` introduction
		var complexKey bool
		keySequences := strings.Split(k, ".")
		keyAccumulator := make([]string, 0, len(keySequences))
		for _, ks := range keySequences {

			if strings.HasPrefix(ks, "\"") {
				// Start Complex key
				keyAccumulator = append(keyAccumulator, ks+"\\")
				complexKey = true

			} else if !strings.HasPrefix(ks, "\"") && !strings.HasSuffix(ks, "\"") && complexKey {
				// Still in the middle of complex key
				keyAccumulator = append(keyAccumulator, strings.Replace(ks, "\"", "\"", -1)+"\\")

			} else if strings.HasSuffix(ks, "\"") && complexKey {
				// We Reached the end of complex key so nothing to do. Reset complex sequence
				keyAccumulator = append(keyAccumulator, strings.Replace(ks, "\"", "\"", -1))
				complexKey = false
			} else {
				// Do nothing
				keyAccumulator = append(keyAccumulator, ks)
			}
		}

		cmd.Args = append(cmd.Args, "--set", fmt.Sprintf("%s=%s", strings.Join(keyAccumulator, "."), step.Set[k]))
	}
	return cmd.Args
}
