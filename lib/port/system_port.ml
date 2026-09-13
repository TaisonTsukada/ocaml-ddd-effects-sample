(** システム系の Port の「語彙」。Port が増えても同じ {!Locator.action} に生やしていく。 *)

open User_api_domain

type _ Locator.action += Ping : (unit, [> Errors.t ]) result Locator.action
