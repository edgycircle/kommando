CREATE TABLE kommando_scheduled_commands (
  id uuid NOT NULL,
  name character varying NOT NULL,
  parameters json NOT NULL,
  handle_at timestamp without time zone NOT NULL,
  failures json[] NOT NULL,
  wait_for_command_ids uuid[] DEFAULT '{}'::uuid[],

  PRIMARY KEY (id)
);

CREATE INDEX index_kommando_scheduled_commands_on_handle_at ON kommando_scheduled_commands USING btree (handle_at);
