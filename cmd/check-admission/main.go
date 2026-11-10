// Command check-admission fails unless every public procedure declares the
// callers it accepts (admission.v1.admits). It reads a Buf image, such as
// `buf build -o -`, from standard input, so a product checks its own public
// contracts the same way:
//
//	buf build -o - | go run github.com/talgent-work/contracts/cmd/check-admission
package main

import (
	"fmt"
	"io"
	"os"
	"strings"

	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/descriptorpb"

	admissionv1 "github.com/talgent-work/contracts/gen/go/admission/v1"
)

func main() {
	image, err := io.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintln(os.Stderr, "check-admission: read image:", err)
		os.Exit(2)
	}
	problems, err := check(image)
	if err != nil {
		fmt.Fprintln(os.Stderr, "check-admission:", err)
		os.Exit(2)
	}
	for _, problem := range problems {
		fmt.Fprintln(os.Stderr, problem)
	}
	if len(problems) > 0 {
		fmt.Fprintf(os.Stderr, "%d public procedure(s) without a valid admission declaration\n", len(problems))
		os.Exit(1)
	}
}

// check lists the public procedures of the image whose admission is missing
// or invalid: a declaration names at least one Principal, or is anonymous and
// names none.
func check(image []byte) ([]string, error) {
	files := &descriptorpb.FileDescriptorSet{}
	if err := proto.Unmarshal(image, files); err != nil {
		return nil, fmt.Errorf("parse image: %w", err)
	}
	var problems []string
	for _, file := range files.GetFile() {
		if !public(file.GetPackage()) {
			continue
		}
		for _, service := range file.GetService() {
			for _, method := range service.GetMethod() {
				procedure := fmt.Sprintf("/%s.%s/%s", file.GetPackage(), service.GetName(), method.GetName())
				if problem := invalid(method.GetOptions()); problem != "" {
					problems = append(problems, fmt.Sprintf("%s (%s): %s", procedure, file.GetName(), problem))
				}
			}
		}
	}
	return problems, nil
}

// public reports whether a proto package is a public surface, <context>.public.vN.
func public(pkg string) bool {
	parts := strings.Split(pkg, ".")
	return len(parts) >= 3 && parts[len(parts)-2] == "public"
}

func invalid(options *descriptorpb.MethodOptions) string {
	if options == nil || !proto.HasExtension(options, admissionv1.E_Admits) {
		return "no admission.v1.admits declaration"
	}
	admits, _ := proto.GetExtension(options, admissionv1.E_Admits).(*admissionv1.Admission)
	principals := admits.GetPrincipals()
	for _, principal := range principals {
		if principal == admissionv1.Principal_PRINCIPAL_UNSPECIFIED {
			return "declares PRINCIPAL_UNSPECIFIED"
		}
	}
	switch {
	case admits.GetAnonymous() && len(principals) > 0:
		return "is anonymous and names Principals"
	case !admits.GetAnonymous() && len(principals) == 0:
		return "names no Principal"
	}
	return ""
}
