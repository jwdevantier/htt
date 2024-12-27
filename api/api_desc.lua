local M = {}


M.htt = {
	content = {}
}
local htt = M.htt

htt.content = {
	{
		name = "EnumValue",
		type = "type",
		fields = {
			{ name = "label", type = "string", summary = "string representation of this enum value" }
		},
		define = false,
		operators = {
			{ definition = "tostring", returns = "string" }
		}
	},
	{
		name      = "Enum",
		type      = "type",
		define    = "false",
		-- TODO: LuaCATS - seems like tostring is not an operator
		operators = {
			{ definition = "tostring", returns = "string" }
		}
	},
	{
		name = "enum",
		type = "function",
		params = {
			{ name = "values", type = "string[]", summary = "list of possible values for new enum" }
		},
		desc = {
			"Create a new enum from a list of string values"
		},
		returns = {
			{ type = "htt.Enum", summary = "the new enumeration value" }
		}
	}
}

local m_str = {
	name = "str",
	type = "module",
	content = {},
}

m_str.content = {
	{
		name = "join",
		type = "function",
		params = {
			{ name = "sep",  type = "string", summary = "string to insert between each concatenated element" },
			{ name = "list", type = "table",  summary = "a list of strings to concatenate" },
		},
		desc = {
			"True iff. `value` is null.",
		},
		returns = {
			{ type = "string", summary = "concatenated strings" }
		},
	},
	{
		name = "stringify",
		type = "function",
		params = {
			{ name = "value",       type = "any",    summary = "The Lua value to stringify (table, string, number, etc.)" },
			{ name = "indentation", type = "string", summary = "The base indentation prefix for each line of output" },
		},
		desc = {
			"Converts a Lua value into a formatted string representation with proper indentation.",
			"",
			"Note: handles the formatting of tables and strings. Will use tostring() otherwise."
		},
		returns = {
			{ type = "string", summary = "The formatted string representation of the value" }
		},
	},
	{
		name = "starts_with",
		type = "function",
		params = {
			{ name = "str",    type = "string", summary = "The string to check" },
			{ name = "prefix", type = "string", summary = "The prefix to look for at the start of the string" },
		},
		desc = {
			"Returns whether the string begins with the specified prefix",
		},
		returns = {
			{ type = "boolean", summary = "true if str starts with prefix, false otherwise" }
		},
	},
}

local m_env = {
	name = "env",
	type = "module",
	content = {},
}

m_env.content = {
	{
		name = "api_version",
		type = "function",
		params = {},
		desc = {
			"Return major- and minor version of the HTT API",
			"",
			"The scheme is thus:",
			"The major version is incremented when *existing* APIs change",
			"The minor version is incremented when new APIs are added",
		},
		returns = {
			{ name = "major", type = "integer", summary = "the API major version" },
			{ name = "minor", type = "integer", summary = "the API minor version" },
		}
	},
	{
		name = "htt_path",
		type = "function",
		params = {},
		desc = {
			"Return path to the HTT binary running the script.",
			"",
			"This can be useful if you want to call HTT on another script to parse in an isolated process"
		},
		returns = {
			{ name = "htt_bin_path", type = "string", summary = "absolute path to the HTT binary" }
		}
	},
	{
		name = "out_path",
		type = "function",
		params = {},
		desc = {
			"Return path to the base output directory.",
			"",
			"HTT determines a base output path which is the base path from which all relative",
			"output paths from calls to `render` will place their files.",
			"",
			"By default, this path is the same directory as the script being run, but command-line",
			"flags can override this.",
		},
		returns = {
			{ name = "out_path", type = "string", summary = "absolute path to the output directory" }
		}
	}
}

local m_tcp = {
	name = "tcp",
	type = "module",
	content = {},
}

local t_tcp_stream = "htt.tcp.Stream"
local t_tcp_buffer = "htt.tcp.Buffer"

local tcp_stream = {
	name = "Stream",
	type = "type",
	content = {
		{
			name = "recv",
			type = "function",
			params = {
				{ name = "buf", type = t_tcp_buffer, summary = "Buffer of data to send" },
				{ name = "n",   type = "integer",    summary = "if provided, read exactly `n` bytes" },
			},
			desc = {
				"Receive data from TCP stream"
			},
			returns = {
				{ type = "integer?", summary = "number of bytes sent" },
				{ type = "string?",  summary = "error message, on error" },
			}
		},
		{
			name = "recv_at_least",
			type = "function",
			params = {
				{ name = "buf", type = t_tcp_buffer, summary = "Buffer of data to send" },
				{ name = "n",   type = "integer",    summary = "read at least this many bytes" },
			},
			desc = {
				"Receive at least N bytes from TCP stream"
			},
			returns = {
				{ type = "integer?", summary = "number of bytes sent" },
				{ type = "string?",  summary = "error message, on error" },
			}
		},
		{
			name = "send",
			type = "function",
			params = {
				{ name = "buffer", type = t_tcp_buffer, summary = "Buffer" },
				{ name = "n",      type = "integer?",   summary = "if set, send the first n bytes, not entire buffer" },
			},
			desc = {
				"Send bytes over TCP stream"
			},
			returns = {
				{ type = "string?", name = "error", summary = "error message, if any" }
			}
		}
	},
}

local tcp_buffer = {
	name = "Buffer",
	type = "type",
	content = {
		{
			name = "remaining",
			type = "function",
			params = {
			},
			desc = {
				"Return number of bytes between current position and end of buffer",
				"",
				"NOTE: the position is modified by `seek()` and reported by `tell()`",
			},
			returns = {
				{ type = "integer?", summary = "Number of bytes from current position to end of buffer" }
			}
		},
		{
			name = "size",
			type = "function",
			params = {
			},
			desc = {
				"Return current size of the buffer in bytes.",
				"",
				"NOTE: Use setSize to grow or shrink the buffer.",
			},
			returns = {
				{ type = "integer?", summary = "Size of buffer in bytes" }
			}
		},
		{
			name = "set_size",
			type = "function",
			params = {
				{ name = "N", type = "integer", "Desired size of the buffer, in bytes" }
			},
			desc = {
				"Return current size of the buffer in bytes.",
				"",
				"NOTE: Use setSize to grow or shrink the buffer.",
			},
			returns = {
				{ type = "integer?", summary = "Size of buffer in bytes" }
			}
		},
		{
			name = "seek",
			type = "function",
			params = {
				{ name = "N", type = "integer", summary = "The byte offset to seek to" }
			},
			desc = {
				"Sets the buffer position to N bytes from the start",
			},
			returns = {
			}
		},
		{
			name = "tell",
			type = "function",
			params = {
			},
			desc = {
				"Reports the offset, in bytes, from the start of the buffer.",
			},
			returns = {
				{ name = "position", type = "integer", summary = "offset, in bytes, from the buffer's start" }
			}
		},
		{
			name = "write_string",
			type = "function",
			params = {
				{ name = "str", type = "string", summary = "the string to write" }
			},
			desc = {
				"Write string to buffer.",
				"",
				"Raises an error if writing the string would go out-of-bounds."
			},
			returns = {
			}
		},
		{
			name = "write_bool",
			type = "function",
			params = {
				{ name = "val", type = "boolean", summary = "the value to write" }
			},
			desc = {
				"Write boolean to buffer.",
				"",
				"Raises an error if writing the boolean would go out-of-bounds."
			},
			returns = {
			}
		},
		{
			name = "read_string",
			type = "function",
			params = {
				{ name = "len", type = "integer", summary = "length, in bytes, of string" }
			},
			desc = {
				"Read `len` bytes from buffer and return it as a string.",
				"",
				"Raises an error if reading the string would go out-of-bounds."
			},
			returns = {
				{ type = "string", summary = "the string value" }
			}
		},
		{
			name = "read_bool",
			type = "function",
			params = {
			},
			desc = {
				"Read boolean value from buffer",
				"",
				"Reads a full byte, anything but 0 is treated as true."
			},
			returns = {
				{ type = "boolean", summary = "the boolean value" }
			}
		},
	}
}

for _, signedness in ipairs({ "i", "u" }) do
	for _, order in ipairs({ "be", "le", "" }) do
		for _, bits in ipairs({ "8", "16", "32", "64" }) do
			local int_desc = string.format(
				"Write %s %s bits integer to buffer",
				signedness == "i" and "signed" or "unsigned",
				bits
			)
			if order ~= "" then
				int_desc = string.format("%s in %s order", int_desc, order == "be" and "big-endian" or "little-endian")
			end
			table.insert(tcp_buffer.content, {
				name = string.format("write_%s%s%s", signedness, bits, order),
				type = "function",
				params = {
					{ name = "val", type = "integer", summary = "value to write" },
				},
				desc = {
					int_desc,
					"",
					"Raises error if writing value would be out-of-bounds"
				},
				returns = {}
			})
		end
	end
end


for _, signedness in ipairs({ "i", "u" }) do
	for _, order in ipairs({ "be", "le", "" }) do
		for _, bits in ipairs({ "8", "16", "32", "64" }) do
			local int_desc = string.format(
				"Reads a %s %s bits integer from buffer",
				signedness == "i" and "signed" or "unsigned",
				bits
			)
			local ret_desc = "the integer value"
			if order ~= "" then
				int_desc = string.format("%s, converts from %s- to native byte-order", int_desc,
					order == "be" and "big-endian" or "little-endian")
				ret_desc = ret_desc .. " converted to native byte order"
			end
			table.insert(tcp_buffer.content, {
				name = string.format("read_%s%s%s", signedness, bits, order),
				type = "function",
				params = {
				},
				desc = {
					int_desc,
					"",
					"Raises error if reading value would be out-of-bounds"
				},
				returns = {
					{ type = "integer", summary = ret_desc },
				}
			})
		end
	end
end


m_tcp.content = {
	{
		name = "Endpoint",
		type = "alias",
		desc = {
			"Value representing an IP address and port"
		},
		def = "userdata", -- a Zig-type, opaque to Lua
	},
	tcp_stream,
	tcp_buffer,
	{
		name = "buffer",
		type = "function",
		params = {
			{ name = "size", type = "integer", summary = "initial size, in bytes, of buffer" }
		},
		desc = {
			"Create a new buffer object",
			"",
			"Buffers can grow and shrink, but only in response to explicit `set_size` calls.",
			"Otherwise, attempting to read- or write past buffer bounds will raise an error.",
			"",
			"A buffer maintains a position, which marks the start of every read- and write",
			"operation. Every read- and write- operation will appropriately advance the position.",
			"To get the position, call `tell()`, which returns some value between 0 and the buffer's size.",
			"You can also manually change the position by calling `seek(N)`."
		},
		returns = {
			{ name = "buf", type = t_tcp_buffer, summary = "the new buffer object" },
			{ name = "err", type = "string?",    summary = "error message, if any" }
		}
	},
	{
		name = "addr",
		type = "function",
		params = {
			{ name = "ip",   type = "string",  summary = "the IPv4/IPv6 address" },
			{ name = "port", type = "integer", summary = "the port of the server" },
		},
		desc = {
			"Returns an address structure which can be passed to `connect`.",
		},
		returns = {
			{ type = "Endpoint", summary = "reference to the endpoint (IP and port), if successful" },
			{ type = "string",   summary = "error message, if any" },
		}
	},
	{
		name = "connect",
		type = "function",
		params = {
			{ name = "endpoint", type = "Endpoint", summary = "structure representing the endpoint" },
		},
		desc = {
			"Connect to a TCP server at the IP-address and port specified by `endpoint`"
		},
		returns = {
			{ name = "stream", type = t_tcp_stream, summary = "stream with which to communicate with the server." },
			{ name = "error",  type = "string",     summary = "error message, if any occurred." },
		}
	}
}

local m_time = {
	name = "time",
	type = "module",
	content = {},
}

m_time.content = {
	{
		name = "nanosecond",
		type = "alias",
		def = "integer",
		desc = {
			"a value meaning some number of nanoseconds"
		},
	},
	{
		name = "timestamp",
		type = "function",
		params = {},
		desc = {
			"Return time, in seconds, relative to UTC 1970-01-01.",
			"",
			"Return-value is signed because it is possible to have dates before the epoch",
		},
		returns = {
			{ name = "time_s", type = "integer", summary = "seconds since the epoch" }
		}
	},
	{
		name = "timestamp_ms",
		type = "function",
		params = {},
		desc = {
			"Return time, in milliseconds, relative to UTC 1970-01-01.",
			"",
			"Return-value is signed to allow for dates before the epoch.",
		},
		returns = {
			{ name = "time_ms", type = "integer", summary = "milliseconds since the epoch" }
		}
	},
	{
		name = "sleep",
		type = "function",
		params = {
			{ name = "duration_ns", type = "nanosecond", summary = "duration, in nanoseconds, to sleep" },
		},
		desc = {
			"Sleep for some duration of time measured in nanoseconds*.",
			"",
			"Underlying implementation mentions that spurious wakeups are possible",
			"and that no precision of timing is guaranteed."
		},
		returns = {}
	},
	{
		name = "ns_per_us",
		type = "constant",
		desc = {
			"The number of nanoseconds per microsecond."
		},
		luatype = "nanosecond",
	},
	{
		name = "ns_per_ms",
		type = "constant",
		desc = {
			"The number of nanoseconds per millisecond."
		},
		luatype = "nanosecond",
	},
	{
		name = "ns_per_s",
		type = "constant",
		desc = {
			"The number of nanoseconds per second."
		},
		luatype = "nanosecond",
	},
	{
		name = "ns_per_min",
		type = "constant",
		desc = {
			"The number of nanoseconds per minute."
		},
		luatype = "nanosecond",
	},
}

local m_fs = {
	name = "fs",
	type = "module",
	content = {},
}

m_fs.content = {
	{
		name = "ftype",
		type = "type",
		define = false,
		fields = {
			{ name = "label", type = "string", summary = "string representation of enum value" }
		}

	},
	{
		name = "DirIterator",
		type = "alias",
		def = "fun(): path, htt.fs.ftype",
		desc = {
			"An iterator function returning pairs of path and 'file' type",
			"",
			"An iterator function which, when called, returns a pair of values",
			"until such time as there are no more values.",
			"",
			"The path value is the file-system path to the entry (file or directory)",
			"and the ftype value is an enumeration type describing the actual type of",
			"the entry, notably whether a file or directory."
		},
	},
	{
		name = "path",
		type = "alias",
		def = "string",
		desc = {
			"A string representing some file system path.",
			"",
			"Note that the actual path separator string can be gotten with htt.fs.sep."
		},
	},
	{
		name = "cwd",
		type = "function",
		params = {},
		desc = {
			"Return handle to directory at current working directory (CWD)."
		},
		returns = {
			{ name = "dir", type = "htt.fs.Dir", summary = "handle to current working directory" }
		}
	},
	{
		name = "sep",
		type = "constant",
		desc = {
			"The string used for path separation on this platform."
		},
		luatype = "string"
	},
	{
		name = "path",
		type = "function",
		params = {
			{ name = "path", type = "path", summary = "file-system path with '/' used as path separator" },
		},
		desc = {
			"Convert `path` from using '/' to using the OS-dependent path separator."
		},
		returns = {
			{ type = "path", summary = "path converted to using OS-dependent path separator" }
		}
	},
	{
		name = "path_join",
		type = "function",
		params = {
			{ name = "...", type = "string", summary = "path components" }
		},
		desc = {
			"Joins a series of path components into a path using the OS-specific path separator"
		},
		returns = {
			{ type = "path", summary = "joined path" }
		}
	},
	{
		name = "dirname",
		type = "function",
		params = {
			{ name = "path", type = "path", summary = "file-system path string" }
		},
		desc = {
			"Given a path, strips last component from path and returns it",
			"",
			"If path is the root directory, returns the empty string."
		},
		returns = {
			{ type = "path", summary = "path to parent directory" }
		}
	},
	{
		name = "basename",
		type = "function",
		params = {
			{ name = "path", type = "path", summary = "file-system path string" }
		},
		desc = {
			"Returns the last component of a file path, excluding trailing separators.",
			"",
			"Returns empty string if applied to root path or root of drive."
		},
		returns = {
			{ type = "string", summary = "name of last component in path" }
		}
	},
	{
		name = "null_file",
		type = "function",
		params = {
		},
		desc = {
			"Returns the OS-specific 'null' file, such as /dev/null for POSIX-compliant systems."
		},
		returns = {
			{ type = "path", summary = "path to null file" }
		}
	},
	{
		name = "Dir",
		type = "type",
		content = {
			{
				name = "path",
				type = "function",
				params = {
				},
				desc = {
					"Get canonical absolute path to this directory.",
				},
				returns = {
					{ type = "path?", summary = "path on success, nil otherwise" }
				}
			},
			{
				name = "make_path",
				type = "function",
				params = {
					{ name = "subpath", type = "path", summary = "path of dirs, relative to dir, to create" },
				},
				desc = {
					"Iteratively creates directory at every level of the provided sub path.",
					"",
					"Returns success if path already exists and is a directory.",
				},
				returns = {
					{ type = "nil",     summary = "always nil" },
					{ type = "string?", summary = "error message, if error" }
				}
			},
			{
				name = "open_dir",
				type = "function",
				params = {
					{ name = "subpath", type = "string", summary = "path relative to dir of directory to open" },
				},
				desc = {
					"Open directory at `subpath`."
				},
				returns = {
					{ name = "directory", type = "htt.fs.Dir", summary = "handle to the opened directory" },
					{ name = "error",     type = "string?",    summary = "error message, if any" },
				}
			},
			{
				name = "parent",
				type = "function",
				params = {
				},
				desc = {
					"Open parent directory."
				},
				returns = {
					{ name = "directory", type = "htt.fs.Dir", summary = "handle to the opened directory" },
					{ name = "error",     type = "string?",    summary = "error message, if any" },
				}
			},
			{
				name = "list",
				type = "function",
				params = {},
				desc = {
					"Return iterator to loop over all items in directory.",
				},
				returns = {
					{ name = "it",    type = "htt.fs.DirIterator", summary = "iterator for iterating over all items in directory" },
					{ name = "error", type = "string?",            summary = "error message, if any" }
				}
			},
			{
				name = "walk",
				type = "function",
				params = {},
				desc = {
					"Return iterator for recursively iterating through all contents nested under dir.",
				},
				returns = {
					{ name = "it",    type = "htt.fs.DirIterator", summary = "iterator for recursively iterate over a directory" },
					{ name = "error", type = "string?",            summary = "error message, if any" },
				}
			},
			{
				name = "remove",
				type = "function",
				params = {
					{ name = "subpath", type = "string?", summary = "(optional) a path relative to this directory. Otherwise this directory." }
				},
				desc = {
					"Remove item at subpath (or directory itself).",
					"",
					"For directories, this will recursively remove the directory itself and all its contents."
				},
				returns = {
					{ type = "nil",   summary = "unused" },
					{ name = "error", type = "string?",  summary = "error message, if any" }
				}
			},
			{
				name = "exists",
				type = "function",
				params = {
					{ name = "subpath", type = "string?", summary = "(optional) either check subpath relative to directory, or directory itself" },
				},
				desc = {
					"Return true if item at subpath, relative to directory, exists."
				},
				returns = {
					{ type = "boolean", summary = "true if an item at subpath exists" },
					{ name = "error",   type = "string?",                             summary = "error message, if any" }
				}
			},
			{
				name = "touch",
				type = "function",
				params = {
					{ name = "subpath", type = "string", summary = "path of file to create, relative to directory" },
				},
				desc = {
					"Create file at subpath, relative to directory.",
				},
				returns = {
					{ type = "nil",   summary = "unused" },
					{ name = "error", type = "string?",  summary = "error message, if any" }
				}
			}
		}
	}
}

local m_tpl = {
	name = "tpl",
	type = "module",
	content = {},
}

local m_is_ret_validator = {
	{ label = "ok",  type = "boolean", summary = "a boolean, true if the value was deemed valid" },
	{ label = "err", type = "string?", summary = "error message if validation failed" }
}

local _validator_fn_type = "ValidatorFn"
local m_is_ret_validator_fn = {
	{ label = "validator", type = _validator_fn_type, summary = "validator function" }
}

local m_is = {
	name = "is",
	type = "module",
	desc = {
		"Validate data through composable predicate functions describing the shape of data.",
		"",
		"You get to declaratively describe, through composable validation functions, the valid shape(s)",
		"of data, useful for constraining the data input (the model) to your templates."
	}
}

m_is.content = {
	{
		type = "alias",
		name = _validator_fn_type,
		def = "fun (value: any): boolean, string?",
		desc = {
			"Function used to determine if value conforms to some specification",
			"",
			"A validator function returns a pair of values, a boolean which is",
			"true iff the value conforms to the specification and (optionally)",
			"a string message, describing the issue if the value does not conform.",
		},
	},
	{
		type = "alias",
		name = "PredicateFn",
		def = "fun (value: any) boolean",
		desc = {
			"Function which, given a value returns true if test succeeds, false otherwise."
		},
	},
	{
		name = "null",
		type = "function",
		params = {
			{ name = "value", type = "any", summary = "some input value to test" },
		},
		desc = {
			"True iff. `value` is null.",
		},
		returns = m_is_ret_validator,
	},
	{
		name = "boolean",
		type = "function",
		params = {
			{ name = "value", type = "any", summary = "some input value to test" },
		},
		desc = {
			"True iff. `value` is a boolean.",
		},
		returns = m_is_ret_validator,
	},
	{
		name = "number",
		type = "function",
		params = {
			{ name = "value", type = "any", summary = "some input value to test" },
		},
		desc = {
			"True iff. `value` is a number.",
		},
		returns = m_is_ret_validator,
	},
	{
		name = "string",
		type = "function",
		params = {
			{ name = "value", type = "any", summary = "some input value to test" },
		},
		desc = {
			"True iff. `value` is a string.",
		},
		returns = m_is_ret_validator,
	},
	{
		name = "userdata",
		type = "function",
		params = {
			{ name = "value", type = "any", summary = "some input value to test" },
		},
		desc = {
			"True iff. `value` is a userdata object.",
			"userdata objects are raw blocks of memory created by an external language like C"
		},
		returns = m_is_ret_validator,
	},
	{
		name = "fn",
		type = "function",
		params = {
			{ name = "value", type = "any", summary = "some input value to test" },
		},
		desc = {
			"True iff. `value` is a function.",
		},
		returns = m_is_ret_validator,
	},
	{
		name = "callable",
		type = "function",
		params = {
			{ name = "value", type = "any", summary = "some input value to test" },
		},
		desc = {
			"True iff. `value` is a function.",
		},
		returns = m_is_ret_validator,
	},
	{
		name = "table",
		type = "function",
		params = {
			{ name = "value", type = "any", summary = "some input value to test" },
		},
		desc = {
			"True iff. `value` is a table.",
			"",
			"Note that tables can *also* be callable if they implement the __call metamethod"
		},
		returns = m_is_ret_validator,
	},
	{
		name = "optional",
		type = "function",
		params = {
			{ name = "validator", type = _validator_fn_type, summary = "a validate function like htt.is.null" }
		},
		desc = {
			"Returns a function which tests input value iff. not nil",
		},
		returns = m_is_ret_validator_fn,
	},
	{
		name = "pred",
		type = "function",
		params = {
			{ name = "pred",  type = "PredicateFn", summary = "a predicate function (a function taking a single argument and returning a bool)" },
			{ name = "label", type = "string",      summary = "a label, used to the describe the kind of test `pred` performs, used in the error message if validation fails" },
		},
		desc = {
			"Wraps `pred` and returns a validator function.",
		},
		returns = m_is_ret_validator_fn
	},
	{
		name = "any",
		type = "function",
		params = {
			{ name = "...", type = _validator_fn_type, summary = "one or more validator functions to test again" },
		},
		desc = {
			"Wraps the provided validator functions, returning a new validator which",
			"succeeds if any of the provided validators apply to the provided value.",
			"",
			"Read as: if any of these validator apply, the data is valid.",
		},
		returns = m_is_ret_validator_fn,
	},
	{
		name = "all",
		type = "function",
		params = {
			{ name = "...", type = _validator_fn_type, summary = "one or more validator functions to test again" },
		},
		desc = {
			"Wraps the provided validator functions, returning a new validator which",
			"succeeds if all of the provided validators apply to the provided value.",
			"",
			"Read as: if all of these validators apply, the data is valid."
		},
		returns = m_is_ret_validator_fn
	},
	{
		name = "list_of",
		type = "function",
		params = {
			{ name = "validator", type = _validator_fn_type, summary = "validator to apply to each element of the list" },
		},
		desc = {
			"Wraps the provided validator, returning a validator which succeeds if",
			"provided a list where each element is valid according to `validator`.",
		},
		returns = m_is_ret_validator_fn,
	},
	{
		name = "table_with",
		type = "function",
		params = {
			-- TODO: maybe refine spec as a type of {"key" -> validator_fn}
			{ name = "spec", type = "table", summary = "a table whose keys point to validator functions" },
		},
		desc = {
			"Returns a validator which takes an input value and returns true if value is a table",
			"where for each entry in `spec`, there is a value which conforms to the corresponding validator",
			"",
			"Read as: I want to validate associative tables, I don't care about *all* their entries, but ",
			"         for some of the keys, I want to associate validator functions to constrain valid values.",
			"         An input value (a table) is valid if all entries constrained by a validator function in `spec`",
			"         succeed their validaton.",
		},
		returns = m_is_ret_validator_fn,
	},
	{
		name = "table_of",
		type = "function",
		params = {
			{ name = "keyValidator", type = _validator_fn_type, summary = "validator to apply to each key" },
			{ name = "valValidator", type = _validator_fn_type, summary = "validator to apply to each value" },
		},
		desc = {
			"Returns a validator which succeeds if the input is a table whose keys all succeed when tested",
			"against `keyValidator` and whose values all succeed when tested against `valValidator`."
		},
		returns = m_is_ret_validator_fn,
	},

}

local m_json = {
	name = "json",
	type = "module",
	summary = "JSON de- serialization functions",
	-- desc if applicable, otherwise
	content = {
		{
			name = "loads",
			type = "function",
			desc = {
				"Deserialize `str` to a Lua value, converting values like so:",
				"",
				"*----------------*---------------------*",
				"| JSON           | Lua                 |",
				"*----------------*---------------------*",
				"| object         | table (associative) |",
				"| array          | table (list)        |",
				"| string         | string              |",
				"| number (int)   | integer             |",
				"| number (float) | number              |",
				"| true           | boolean             |",
				"| false          | boolean             |",
				"| null           | nil                 |",
				"*----------------*---------------------*",
			},
			params = {
				{ name = "str", type = "string", summary = "a string of JSON" },
			},
			returns = {
				{ type = "any", summary = "a Lua data-structure reflecting the deserialized JSON" },
			}
		},
		{
			name = "dumps",
			type = "function",
			desc = {
				"Serialize `obj` to a JSON-formatted string.",
				"",
				"See the table in `loads` for information on how values are",
				"converted."
			},
			params = {
				{ name = "obj", type = "any", summary = "some Lua data-structure" },
			},
			returns = {
				{ type = "string", summary = "a JSON-formatted string representing `obj`." }
			}
		},
	}
}

htt.name = "htt"
htt.summary = "HTT utility API"
htt.class = "htt"
htt.content = {
	m_str,
	m_env,
	m_tcp,
	m_time,
	m_fs,
	-- m_tpl,
	m_is,
	m_json,
}

return M
