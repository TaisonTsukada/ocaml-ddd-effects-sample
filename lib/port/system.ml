(** システム系の「語彙」。リポジトリ以外の Port も同じ {!Locator.action} に生やす。 記事で言う [System.Ping]
    にあたる。 *)

open User_api_domain

type _ Locator.action += Ping : (unit, [> Errors.t ]) result Locator.action
