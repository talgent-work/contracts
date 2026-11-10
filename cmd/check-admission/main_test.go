package main

import (
	"testing"

	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/descriptorpb"

	admissionv1 "github.com/talgent-work/contracts/gen/go/admission/v1"
)

func method(name string, admits *admissionv1.Admission) *descriptorpb.MethodDescriptorProto {
	m := &descriptorpb.MethodDescriptorProto{Name: proto.String(name)}
	if admits != nil {
		m.Options = &descriptorpb.MethodOptions{}
		proto.SetExtension(m.Options, admissionv1.E_Admits, admits)
	}
	return m
}

func image(t *testing.T, pkg string, methods ...*descriptorpb.MethodDescriptorProto) []byte {
	t.Helper()
	encoded, err := proto.Marshal(&descriptorpb.FileDescriptorSet{File: []*descriptorpb.FileDescriptorProto{{
		Name: proto.String("x.proto"), Package: proto.String(pkg),
		Service: []*descriptorpb.ServiceDescriptorProto{{Name: proto.String("S"), Method: methods}},
	}}})
	if err != nil {
		t.Fatal(err)
	}
	return encoded
}

func TestEveryPublicProcedureDeclaresItsAdmission(t *testing.T) {
	user := []admissionv1.Principal{admissionv1.Principal_PRINCIPAL_USER}
	for name, tc := range map[string]struct {
		pkg     string
		method  *descriptorpb.MethodDescriptorProto
		refused bool
	}{
		"declared for a Principal":  {pkg: "a.public.v1", method: method("M", &admissionv1.Admission{Principals: user})},
		"anonymous":                 {pkg: "a.public.v1", method: method("M", &admissionv1.Admission{Anonymous: true})},
		"undeclared":                {pkg: "a.public.v1", method: method("M", nil), refused: true},
		"declares nothing":          {pkg: "a.public.v1", method: method("M", &admissionv1.Admission{}), refused: true},
		"anonymous and a Principal": {pkg: "a.public.v1", method: method("M", &admissionv1.Admission{Anonymous: true, Principals: user}), refused: true},
		"unspecified":               {pkg: "a.public.v1", method: method("M", &admissionv1.Admission{Principals: []admissionv1.Principal{0}}), refused: true},
		"private needs none":        {pkg: "a.private.v1", method: method("M", nil)},
	} {
		t.Run(name, func(t *testing.T) {
			problems, err := check(image(t, tc.pkg, tc.method))
			if err != nil {
				t.Fatal(err)
			}
			if refused := len(problems) > 0; refused != tc.refused {
				t.Fatalf("refused = %v, want %v: %v", refused, tc.refused, problems)
			}
		})
	}
}
