module github.com/MChorfa/porter-helm3

go 1.13

require (
	cloud.google.com/go v0.55.0 // indirect
	get.porter.sh/porter v0.23.0-beta.1
	github.com/Masterminds/semver v1.5.0
	github.com/PaesslerAG/gval v1.0.1 // indirect
	github.com/PuerkitoBio/goquery v1.5.1 // indirect
	github.com/ghodss/yaml v1.0.0
	github.com/gobuffalo/packr/v2 v2.8.1
	github.com/googleapis/gnostic v0.5.3 // indirect
	github.com/hashicorp/go-multierror v1.0.0
	github.com/imdario/mergo v0.3.8 // indirect
	github.com/karrick/godirwalk v1.16.1 // indirect
	github.com/pkg/errors v0.9.1
	github.com/rogpeppe/go-internal v1.8.0 // indirect
	github.com/sirupsen/logrus v1.8.1 // indirect
	github.com/spf13/cobra v1.1.3
	github.com/stretchr/testify v1.6.1
	github.com/xeipuuv/gojsonpointer v0.0.0-20190905194746-02993c407bfb // indirect
	github.com/xeipuuv/gojsonschema v1.2.0
	golang.org/x/crypto v0.0.0-20210421170649-83a5a9bb288b // indirect
	golang.org/x/sync v0.0.0-20210220032951-036812b2e83c // indirect
	golang.org/x/sys v0.0.0-20210426230700-d19ff857e887 // indirect
	golang.org/x/term v0.0.0-20210429154555-c04ba851c2a4 // indirect
	gopkg.in/yaml.v2 v2.4.0
	k8s.io/apimachinery v0.21.0
	k8s.io/client-go v0.21.0
)

replace github.com/hashicorp/go-plugin => github.com/carolynvs/go-plugin v1.0.1-acceptstdin
