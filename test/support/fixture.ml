(** テスト用の fixture と Alcotest testable。 *)

module User = User_api_domain.Objects.User
module Errors = User_api_domain.Errors

(* 記事 §5 と同じく、検証済みと分かっている値の組み立てだけに unsafe_from を使う。 *)

let name_of = User.Name.unsafe_from
let email_of = User.Email.unsafe_from
let id_of = User.Id.from

let user ?(id = 1) ?(name = "nymphium") ?(email = "nymphium@example.com") () =
  {
    User.id = User.Id.from id;
    name = User.Name.unsafe_from name;
    email = User.Email.unsafe_from email;
  }

let user_t = Alcotest.testable User.pp User.equal
let name_t = Alcotest.testable User.Name.pp User.Name.equal
let email_t = Alcotest.testable User.Email.pp User.Email.equal
let id_t = Alcotest.testable User.Id.pp User.Id.equal
let errors_t = Alcotest.testable Errors.pp Errors.equal
