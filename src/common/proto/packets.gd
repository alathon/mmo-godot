#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value

	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		if data_type == PB_DATA_TYPE.FLOAT:
			return bytes.decode_float(index)
		elif data_type == PB_DATA_TYPE.DOUBLE:
			return bytes.decode_double(index)
		else:
			# Convert to big endian
			var slice: PackedByteArray = bytes.slice(index, index + count)
			slice.reverse()
			return slice

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		var i: int = varint_bytes.size() - 1
		while i > -1:
			value = (value << 7) | (varint_bytes[i] & 0x7F)
			i -= 1
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var i: int = index
		while i <= index + 10: # Protobuf varint max size is 10 bytes
			if !(bytes[i] & 0x80):
				return bytes.slice(index, i + 1)
			i += 1
		return [] # Unreachable

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
			var length : int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
				else:
					var res : int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
						offset = res
						if offset == limit:
							return offset
						elif offset > limit:
							return PB_ERR.PACKAGE_SIZE_MISMATCH
					elif res < 0:
						return res
					else:
						break
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result

	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text

	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result

	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result

	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


enum DecayType {
	DECAY_LINEAR = 0,
	DECAY_EXPONENTIAL = 1
}

class Impulse:
	func _init():
		var service

		__vel_x = PBField.new("vel_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_x
		data[__vel_x.tag] = service

		__vel_y = PBField.new("vel_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_y
		data[__vel_y.tag] = service

		__vel_z = PBField.new("vel_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_z
		data[__vel_z.tag] = service

		__start_tick = PBField.new("start_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __start_tick
		data[__start_tick.tag] = service

		__duration_ticks = PBField.new("duration_ticks", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __duration_ticks
		data[__duration_ticks.tag] = service

		__decay_type = PBField.new("decay_type", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __decay_type
		data[__decay_type.tag] = service

	var data = {}

	var __vel_x: PBField
	func has_vel_x() -> bool:
		if __vel_x.value != null:
			return true
		return false
	func get_vel_x() -> float:
		return __vel_x.value
	func clear_vel_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__vel_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_x(value : float) -> void:
		__vel_x.value = value

	var __vel_y: PBField
	func has_vel_y() -> bool:
		if __vel_y.value != null:
			return true
		return false
	func get_vel_y() -> float:
		return __vel_y.value
	func clear_vel_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__vel_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_y(value : float) -> void:
		__vel_y.value = value

	var __vel_z: PBField
	func has_vel_z() -> bool:
		if __vel_z.value != null:
			return true
		return false
	func get_vel_z() -> float:
		return __vel_z.value
	func clear_vel_z() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__vel_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_z(value : float) -> void:
		__vel_z.value = value

	var __start_tick: PBField
	func has_start_tick() -> bool:
		if __start_tick.value != null:
			return true
		return false
	func get_start_tick() -> int:
		return __start_tick.value
	func clear_start_tick() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__start_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_start_tick(value : int) -> void:
		__start_tick.value = value

	var __duration_ticks: PBField
	func has_duration_ticks() -> bool:
		if __duration_ticks.value != null:
			return true
		return false
	func get_duration_ticks() -> int:
		return __duration_ticks.value
	func clear_duration_ticks() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__duration_ticks.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_duration_ticks(value : int) -> void:
		__duration_ticks.value = value

	var __decay_type: PBField
	func has_decay_type() -> bool:
		if __decay_type.value != null:
			return true
		return false
	func get_decay_type():
		return __decay_type.value
	func clear_decay_type() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__decay_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_decay_type(value) -> void:
		__decay_type.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class AbilityInput:
	func _init():
		var service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__target_entity_id = PBField.new("target_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_entity_id
		data[__target_entity_id.tag] = service

		__ground_x = PBField.new("ground_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __ground_x
		data[__ground_x.tag] = service

		__ground_y = PBField.new("ground_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __ground_y
		data[__ground_y.tag] = service

		__ground_z = PBField.new("ground_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __ground_z
		data[__ground_z.tag] = service

		__request_id = PBField.new("request_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __request_id
		data[__request_id.tag] = service

	var data = {}

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __target_entity_id: PBField
	func has_target_entity_id() -> bool:
		if __target_entity_id.value != null:
			return true
		return false
	func get_target_entity_id() -> int:
		return __target_entity_id.value
	func clear_target_entity_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__target_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_entity_id(value : int) -> void:
		__target_entity_id.value = value

	var __ground_x: PBField
	func has_ground_x() -> bool:
		if __ground_x.value != null:
			return true
		return false
	func get_ground_x() -> float:
		return __ground_x.value
	func clear_ground_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ground_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_ground_x(value : float) -> void:
		__ground_x.value = value

	var __ground_y: PBField
	func has_ground_y() -> bool:
		if __ground_y.value != null:
			return true
		return false
	func get_ground_y() -> float:
		return __ground_y.value
	func clear_ground_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__ground_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_ground_y(value : float) -> void:
		__ground_y.value = value

	var __ground_z: PBField
	func has_ground_z() -> bool:
		if __ground_z.value != null:
			return true
		return false
	func get_ground_z() -> float:
		return __ground_z.value
	func clear_ground_z() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ground_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_ground_z(value : float) -> void:
		__ground_z.value = value

	var __request_id: PBField
	func has_request_id() -> bool:
		if __request_id.value != null:
			return true
		return false
	func get_request_id() -> int:
		return __request_id.value
	func clear_request_id() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_request_id(value : int) -> void:
		__request_id.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class TargetSelect:
	func _init():
		var service

		__target_entity_id = PBField.new("target_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_entity_id
		data[__target_entity_id.tag] = service

	var data = {}

	var __target_entity_id: PBField
	func has_target_entity_id() -> bool:
		if __target_entity_id.value != null:
			return true
		return false
	func get_target_entity_id() -> int:
		return __target_entity_id.value
	func clear_target_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__target_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_entity_id(value : int) -> void:
		__target_entity_id.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class AbilityUseAccepted:
	func _init():
		var service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__requested_tick = PBField.new("requested_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __requested_tick
		data[__requested_tick.tag] = service

		__start_tick = PBField.new("start_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __start_tick
		data[__start_tick.tag] = service

		__request_id = PBField.new("request_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __request_id
		data[__request_id.tag] = service

		__resolve_tick = PBField.new("resolve_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __resolve_tick
		data[__resolve_tick.tag] = service

		__finish_tick = PBField.new("finish_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __finish_tick
		data[__finish_tick.tag] = service

		__impact_tick = PBField.new("impact_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __impact_tick
		data[__impact_tick.tag] = service

	var data = {}

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __requested_tick: PBField
	func has_requested_tick() -> bool:
		if __requested_tick.value != null:
			return true
		return false
	func get_requested_tick() -> int:
		return __requested_tick.value
	func clear_requested_tick() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__requested_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_requested_tick(value : int) -> void:
		__requested_tick.value = value

	var __start_tick: PBField
	func has_start_tick() -> bool:
		if __start_tick.value != null:
			return true
		return false
	func get_start_tick() -> int:
		return __start_tick.value
	func clear_start_tick() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__start_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_start_tick(value : int) -> void:
		__start_tick.value = value

	var __request_id: PBField
	func has_request_id() -> bool:
		if __request_id.value != null:
			return true
		return false
	func get_request_id() -> int:
		return __request_id.value
	func clear_request_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__request_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_request_id(value : int) -> void:
		__request_id.value = value

	var __resolve_tick: PBField
	func has_resolve_tick() -> bool:
		if __resolve_tick.value != null:
			return true
		return false
	func get_resolve_tick() -> int:
		return __resolve_tick.value
	func clear_resolve_tick() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__resolve_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_resolve_tick(value : int) -> void:
		__resolve_tick.value = value

	var __finish_tick: PBField
	func has_finish_tick() -> bool:
		if __finish_tick.value != null:
			return true
		return false
	func get_finish_tick() -> int:
		return __finish_tick.value
	func clear_finish_tick() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__finish_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_finish_tick(value : int) -> void:
		__finish_tick.value = value

	var __impact_tick: PBField
	func has_impact_tick() -> bool:
		if __impact_tick.value != null:
			return true
		return false
	func get_impact_tick() -> int:
		return __impact_tick.value
	func clear_impact_tick() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__impact_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_impact_tick(value : int) -> void:
		__impact_tick.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class AbilityUseRejected:
	func _init():
		var service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__requested_tick = PBField.new("requested_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __requested_tick
		data[__requested_tick.tag] = service

		__cancel_reason = PBField.new("cancel_reason", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __cancel_reason
		data[__cancel_reason.tag] = service

		__request_id = PBField.new("request_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __request_id
		data[__request_id.tag] = service

	var data = {}

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __requested_tick: PBField
	func has_requested_tick() -> bool:
		if __requested_tick.value != null:
			return true
		return false
	func get_requested_tick() -> int:
		return __requested_tick.value
	func clear_requested_tick() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__requested_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_requested_tick(value : int) -> void:
		__requested_tick.value = value

	var __cancel_reason: PBField
	func has_cancel_reason() -> bool:
		if __cancel_reason.value != null:
			return true
		return false
	func get_cancel_reason() -> int:
		return __cancel_reason.value
	func clear_cancel_reason() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__cancel_reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_cancel_reason(value : int) -> void:
		__cancel_reason.value = value

	var __request_id: PBField
	func has_request_id() -> bool:
		if __request_id.value != null:
			return true
		return false
	func get_request_id() -> int:
		return __request_id.value
	func clear_request_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__request_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_request_id(value : int) -> void:
		__request_id.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

enum ResolvedAbilityEffectKind {
	RESOLVED_EFFECT_DAMAGE = 0,
	RESOLVED_EFFECT_HEAL = 1,
	RESOLVED_EFFECT_STATUS = 2
}

enum ResolvedAbilityEffectPhase {
	RESOLVED_EFFECT_IMPACT = 0,
	RESOLVED_EFFECT_EARLY = 1
}

class ResolvedAbilityEffect:
	func _init():
		var service

		__kind = PBField.new("kind", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __kind
		data[__kind.tag] = service

		__phase = PBField.new("phase", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __phase
		data[__phase.tag] = service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

		__target_entity_id = PBField.new("target_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_entity_id
		data[__target_entity_id.tag] = service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__hit_type = PBField.new("hit_type", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __hit_type
		data[__hit_type.tag] = service

		__amount = PBField.new("amount", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service

		__status_id = PBField.new("status_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __status_id
		data[__status_id.tag] = service

		__duration = PBField.new("duration", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __duration
		data[__duration.tag] = service

		__is_debuff = PBField.new("is_debuff", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_debuff
		data[__is_debuff.tag] = service

	var data = {}

	var __kind: PBField
	func has_kind() -> bool:
		if __kind.value != null:
			return true
		return false
	func get_kind():
		return __kind.value
	func clear_kind() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__kind.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_kind(value) -> void:
		__kind.value = value

	var __phase: PBField
	func has_phase() -> bool:
		if __phase.value != null:
			return true
		return false
	func get_phase():
		return __phase.value
	func clear_phase() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__phase.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_phase(value) -> void:
		__phase.value = value

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	var __target_entity_id: PBField
	func has_target_entity_id() -> bool:
		if __target_entity_id.value != null:
			return true
		return false
	func get_target_entity_id() -> int:
		return __target_entity_id.value
	func clear_target_entity_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__target_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_entity_id(value : int) -> void:
		__target_entity_id.value = value

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __hit_type: PBField
	func has_hit_type() -> bool:
		if __hit_type.value != null:
			return true
		return false
	func get_hit_type():
		return __hit_type.value
	func clear_hit_type() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__hit_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_hit_type(value) -> void:
		__hit_type.value = value

	var __amount: PBField
	func has_amount() -> bool:
		if __amount.value != null:
			return true
		return false
	func get_amount() -> int:
		return __amount.value
	func clear_amount() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_amount(value : int) -> void:
		__amount.value = value

	var __status_id: PBField
	func has_status_id() -> bool:
		if __status_id.value != null:
			return true
		return false
	func get_status_id() -> String:
		return __status_id.value
	func clear_status_id() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__status_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_status_id(value : String) -> void:
		__status_id.value = value

	var __duration: PBField
	func has_duration() -> bool:
		if __duration.value != null:
			return true
		return false
	func get_duration() -> float:
		return __duration.value
	func clear_duration() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__duration.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_duration(value : float) -> void:
		__duration.value = value

	var __is_debuff: PBField
	func has_is_debuff() -> bool:
		if __is_debuff.value != null:
			return true
		return false
	func get_is_debuff() -> bool:
		return __is_debuff.value
	func clear_is_debuff() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__is_debuff.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_debuff(value : bool) -> void:
		__is_debuff.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class AbilityUseResolved:
	func _init():
		var service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__requested_tick = PBField.new("requested_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __requested_tick
		data[__requested_tick.tag] = service

		__start_tick = PBField.new("start_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __start_tick
		data[__start_tick.tag] = service

		__request_id = PBField.new("request_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __request_id
		data[__request_id.tag] = service

		__resolve_tick = PBField.new("resolve_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __resolve_tick
		data[__resolve_tick.tag] = service

		__finish_tick = PBField.new("finish_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __finish_tick
		data[__finish_tick.tag] = service

		__impact_tick = PBField.new("impact_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __impact_tick
		data[__impact_tick.tag] = service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

		var __effects_default: Array[ResolvedAbilityEffect] = []
		__effects = PBField.new("effects", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 9, true, __effects_default)
		service = PBServiceField.new()
		service.field = __effects
		service.func_ref = Callable(self, "add_effects")
		data[__effects.tag] = service

	var data = {}

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __requested_tick: PBField
	func has_requested_tick() -> bool:
		if __requested_tick.value != null:
			return true
		return false
	func get_requested_tick() -> int:
		return __requested_tick.value
	func clear_requested_tick() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__requested_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_requested_tick(value : int) -> void:
		__requested_tick.value = value

	var __start_tick: PBField
	func has_start_tick() -> bool:
		if __start_tick.value != null:
			return true
		return false
	func get_start_tick() -> int:
		return __start_tick.value
	func clear_start_tick() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__start_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_start_tick(value : int) -> void:
		__start_tick.value = value

	var __request_id: PBField
	func has_request_id() -> bool:
		if __request_id.value != null:
			return true
		return false
	func get_request_id() -> int:
		return __request_id.value
	func clear_request_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__request_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_request_id(value : int) -> void:
		__request_id.value = value

	var __resolve_tick: PBField
	func has_resolve_tick() -> bool:
		if __resolve_tick.value != null:
			return true
		return false
	func get_resolve_tick() -> int:
		return __resolve_tick.value
	func clear_resolve_tick() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__resolve_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_resolve_tick(value : int) -> void:
		__resolve_tick.value = value

	var __finish_tick: PBField
	func has_finish_tick() -> bool:
		if __finish_tick.value != null:
			return true
		return false
	func get_finish_tick() -> int:
		return __finish_tick.value
	func clear_finish_tick() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__finish_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_finish_tick(value : int) -> void:
		__finish_tick.value = value

	var __impact_tick: PBField
	func has_impact_tick() -> bool:
		if __impact_tick.value != null:
			return true
		return false
	func get_impact_tick() -> int:
		return __impact_tick.value
	func clear_impact_tick() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__impact_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_impact_tick(value : int) -> void:
		__impact_tick.value = value

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	var __effects: PBField
	func get_effects() -> Array[ResolvedAbilityEffect]:
		return __effects.value
	func clear_effects() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__effects.value.clear()
	func add_effects() -> ResolvedAbilityEffect:
		var element = ResolvedAbilityEffect.new()
		__effects.value.append(element)
		return element

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

enum HitType {
	HIT = 0,
	MISS = 1,
	DODGE = 2,
	CRIT = 3,
	BLOCK = 4,
	CRIT_BLOCK = 5
}

class EntityEvent_AbilityUseStarted:
	func _init():
		var service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__target_entity_id = PBField.new("target_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_entity_id
		data[__target_entity_id.tag] = service

		__ground_x = PBField.new("ground_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __ground_x
		data[__ground_x.tag] = service

		__ground_y = PBField.new("ground_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __ground_y
		data[__ground_y.tag] = service

		__ground_z = PBField.new("ground_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __ground_z
		data[__ground_z.tag] = service

		__cast_time = PBField.new("cast_time", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __cast_time
		data[__cast_time.tag] = service

	var data = {}

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __target_entity_id: PBField
	func has_target_entity_id() -> bool:
		if __target_entity_id.value != null:
			return true
		return false
	func get_target_entity_id() -> int:
		return __target_entity_id.value
	func clear_target_entity_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__target_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_entity_id(value : int) -> void:
		__target_entity_id.value = value

	var __ground_x: PBField
	func has_ground_x() -> bool:
		if __ground_x.value != null:
			return true
		return false
	func get_ground_x() -> float:
		return __ground_x.value
	func clear_ground_x() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__ground_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_ground_x(value : float) -> void:
		__ground_x.value = value

	var __ground_y: PBField
	func has_ground_y() -> bool:
		if __ground_y.value != null:
			return true
		return false
	func get_ground_y() -> float:
		return __ground_y.value
	func clear_ground_y() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ground_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_ground_y(value : float) -> void:
		__ground_y.value = value

	var __ground_z: PBField
	func has_ground_z() -> bool:
		if __ground_z.value != null:
			return true
		return false
	func get_ground_z() -> float:
		return __ground_z.value
	func clear_ground_z() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__ground_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_ground_z(value : float) -> void:
		__ground_z.value = value

	var __cast_time: PBField
	func has_cast_time() -> bool:
		if __cast_time.value != null:
			return true
		return false
	func get_cast_time() -> float:
		return __cast_time.value
	func clear_cast_time() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__cast_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_cast_time(value : float) -> void:
		__cast_time.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent_AbilityUseCanceled:
	func _init():
		var service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__cancel_reason = PBField.new("cancel_reason", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __cancel_reason
		data[__cancel_reason.tag] = service

	var data = {}

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __cancel_reason: PBField
	func has_cancel_reason() -> bool:
		if __cancel_reason.value != null:
			return true
		return false
	func get_cancel_reason() -> int:
		return __cancel_reason.value
	func clear_cancel_reason() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__cancel_reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_cancel_reason(value : int) -> void:
		__cancel_reason.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent_AbilityUseCompleted:
	func _init():
		var service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__hit_type = PBField.new("hit_type", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = __hit_type
		data[__hit_type.tag] = service

	var data = {}

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __hit_type: PBField
	func has_hit_type() -> bool:
		if __hit_type.value != null:
			return true
		return false
	func get_hit_type():
		return __hit_type.value
	func clear_hit_type() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__hit_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_hit_type(value) -> void:
		__hit_type.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent_DamageTaken:
	func _init():
		var service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

		__target_entity_id = PBField.new("target_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_entity_id
		data[__target_entity_id.tag] = service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__amount = PBField.new("amount", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service

	var data = {}

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	var __target_entity_id: PBField
	func has_target_entity_id() -> bool:
		if __target_entity_id.value != null:
			return true
		return false
	func get_target_entity_id() -> int:
		return __target_entity_id.value
	func clear_target_entity_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__target_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_entity_id(value : int) -> void:
		__target_entity_id.value = value

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __amount: PBField
	func has_amount() -> bool:
		if __amount.value != null:
			return true
		return false
	func get_amount() -> float:
		return __amount.value
	func clear_amount() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_amount(value : float) -> void:
		__amount.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent_HealingReceived:
	func _init():
		var service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

		__target_entity_id = PBField.new("target_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_entity_id
		data[__target_entity_id.tag] = service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__amount = PBField.new("amount", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service

	var data = {}

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	var __target_entity_id: PBField
	func has_target_entity_id() -> bool:
		if __target_entity_id.value != null:
			return true
		return false
	func get_target_entity_id() -> int:
		return __target_entity_id.value
	func clear_target_entity_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__target_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_entity_id(value : int) -> void:
		__target_entity_id.value = value

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __amount: PBField
	func has_amount() -> bool:
		if __amount.value != null:
			return true
		return false
	func get_amount() -> float:
		return __amount.value
	func clear_amount() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_amount(value : float) -> void:
		__amount.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent_BuffApplied:
	func _init():
		var service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

		__target_entity_id = PBField.new("target_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_entity_id
		data[__target_entity_id.tag] = service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__status_id = PBField.new("status_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __status_id
		data[__status_id.tag] = service

		__stacks = PBField.new("stacks", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __stacks
		data[__stacks.tag] = service

		__remaining_duration = PBField.new("remaining_duration", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __remaining_duration
		data[__remaining_duration.tag] = service

	var data = {}

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	var __target_entity_id: PBField
	func has_target_entity_id() -> bool:
		if __target_entity_id.value != null:
			return true
		return false
	func get_target_entity_id() -> int:
		return __target_entity_id.value
	func clear_target_entity_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__target_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_entity_id(value : int) -> void:
		__target_entity_id.value = value

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __status_id: PBField
	func has_status_id() -> bool:
		if __status_id.value != null:
			return true
		return false
	func get_status_id() -> String:
		return __status_id.value
	func clear_status_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__status_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_status_id(value : String) -> void:
		__status_id.value = value

	var __stacks: PBField
	func has_stacks() -> bool:
		if __stacks.value != null:
			return true
		return false
	func get_stacks() -> int:
		return __stacks.value
	func clear_stacks() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__stacks.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_stacks(value : int) -> void:
		__stacks.value = value

	var __remaining_duration: PBField
	func has_remaining_duration() -> bool:
		if __remaining_duration.value != null:
			return true
		return false
	func get_remaining_duration() -> float:
		return __remaining_duration.value
	func clear_remaining_duration() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__remaining_duration.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_remaining_duration(value : float) -> void:
		__remaining_duration.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent_DebuffApplied:
	func _init():
		var service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

		__target_entity_id = PBField.new("target_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_entity_id
		data[__target_entity_id.tag] = service

		__ability_id = PBField.new("ability_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ability_id
		data[__ability_id.tag] = service

		__status_id = PBField.new("status_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __status_id
		data[__status_id.tag] = service

		__stacks = PBField.new("stacks", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __stacks
		data[__stacks.tag] = service

		__remaining_duration = PBField.new("remaining_duration", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __remaining_duration
		data[__remaining_duration.tag] = service

	var data = {}

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	var __target_entity_id: PBField
	func has_target_entity_id() -> bool:
		if __target_entity_id.value != null:
			return true
		return false
	func get_target_entity_id() -> int:
		return __target_entity_id.value
	func clear_target_entity_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__target_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_entity_id(value : int) -> void:
		__target_entity_id.value = value

	var __ability_id: PBField
	func has_ability_id() -> bool:
		if __ability_id.value != null:
			return true
		return false
	func get_ability_id() -> String:
		return __ability_id.value
	func clear_ability_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ability_id(value : String) -> void:
		__ability_id.value = value

	var __status_id: PBField
	func has_status_id() -> bool:
		if __status_id.value != null:
			return true
		return false
	func get_status_id() -> String:
		return __status_id.value
	func clear_status_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__status_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_status_id(value : String) -> void:
		__status_id.value = value

	var __stacks: PBField
	func has_stacks() -> bool:
		if __stacks.value != null:
			return true
		return false
	func get_stacks() -> int:
		return __stacks.value
	func clear_stacks() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__stacks.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_stacks(value : int) -> void:
		__stacks.value = value

	var __remaining_duration: PBField
	func has_remaining_duration() -> bool:
		if __remaining_duration.value != null:
			return true
		return false
	func get_remaining_duration() -> float:
		return __remaining_duration.value
	func clear_remaining_duration() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__remaining_duration.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_remaining_duration(value : float) -> void:
		__remaining_duration.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent_StatusEffectRemoved:
	func _init():
		var service

		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service

		__status_id = PBField.new("status_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __status_id
		data[__status_id.tag] = service

		__remove_reason = PBField.new("remove_reason", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __remove_reason
		data[__remove_reason.tag] = service

	var data = {}

	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> int:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_entity_id(value : int) -> void:
		__entity_id.value = value

	var __status_id: PBField
	func has_status_id() -> bool:
		if __status_id.value != null:
			return true
		return false
	func get_status_id() -> String:
		return __status_id.value
	func clear_status_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__status_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_status_id(value : String) -> void:
		__status_id.value = value

	var __remove_reason: PBField
	func has_remove_reason() -> bool:
		if __remove_reason.value != null:
			return true
		return false
	func get_remove_reason() -> int:
		return __remove_reason.value
	func clear_remove_reason() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__remove_reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_remove_reason(value : int) -> void:
		__remove_reason.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent_CombatStarted:
	func _init():
		var service

		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

	var data = {}

	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> int:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_entity_id(value : int) -> void:
		__entity_id.value = value

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent_CombatEnded:
	func _init():
		var service

		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service

	var data = {}

	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> int:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_entity_id(value : int) -> void:
		__entity_id.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent_CombatantDied:
	func _init():
		var service

		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service

		__killer_entity_id = PBField.new("killer_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __killer_entity_id
		data[__killer_entity_id.tag] = service

	var data = {}

	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> int:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_entity_id(value : int) -> void:
		__entity_id.value = value

	var __killer_entity_id: PBField
	func has_killer_entity_id() -> bool:
		if __killer_entity_id.value != null:
			return true
		return false
	func get_killer_entity_id() -> int:
		return __killer_entity_id.value
	func clear_killer_entity_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__killer_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_killer_entity_id(value : int) -> void:
		__killer_entity_id.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityEvent:
	func _init():
		var service

		__tick = PBField.new("tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service

		__ability_use_started = PBField.new("ability_use_started", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __ability_use_started
		service.func_ref = Callable(self, "new_ability_use_started")
		data[__ability_use_started.tag] = service

		__ability_use_canceled = PBField.new("ability_use_canceled", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __ability_use_canceled
		service.func_ref = Callable(self, "new_ability_use_canceled")
		data[__ability_use_canceled.tag] = service

		__ability_use_completed = PBField.new("ability_use_completed", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __ability_use_completed
		service.func_ref = Callable(self, "new_ability_use_completed")
		data[__ability_use_completed.tag] = service

		__damage_taken = PBField.new("damage_taken", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __damage_taken
		service.func_ref = Callable(self, "new_damage_taken")
		data[__damage_taken.tag] = service

		__healing_received = PBField.new("healing_received", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __healing_received
		service.func_ref = Callable(self, "new_healing_received")
		data[__healing_received.tag] = service

		__buff_applied = PBField.new("buff_applied", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __buff_applied
		service.func_ref = Callable(self, "new_buff_applied")
		data[__buff_applied.tag] = service

		__debuff_applied = PBField.new("debuff_applied", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __debuff_applied
		service.func_ref = Callable(self, "new_debuff_applied")
		data[__debuff_applied.tag] = service

		__status_effect_removed = PBField.new("status_effect_removed", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __status_effect_removed
		service.func_ref = Callable(self, "new_status_effect_removed")
		data[__status_effect_removed.tag] = service

		__combatant_died = PBField.new("combatant_died", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __combatant_died
		service.func_ref = Callable(self, "new_combatant_died")
		data[__combatant_died.tag] = service

		__combat_started = PBField.new("combat_started", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __combat_started
		service.func_ref = Callable(self, "new_combat_started")
		data[__combat_started.tag] = service

		__combat_ended = PBField.new("combat_ended", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __combat_ended
		service.func_ref = Callable(self, "new_combat_ended")
		data[__combat_ended.tag] = service

	var data = {}

	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_tick(value : int) -> void:
		__tick.value = value

	var __ability_use_started: PBField
	func has_ability_use_started() -> bool:
		if __ability_use_started.value != null:
			return true
		return false
	func get_ability_use_started() -> EntityEvent_AbilityUseStarted:
		return __ability_use_started.value
	func clear_ability_use_started() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ability_use_started() -> EntityEvent_AbilityUseStarted:
		data[2].state = PB_SERVICE_STATE.FILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_started.value = EntityEvent_AbilityUseStarted.new()
		return __ability_use_started.value

	var __ability_use_canceled: PBField
	func has_ability_use_canceled() -> bool:
		if __ability_use_canceled.value != null:
			return true
		return false
	func get_ability_use_canceled() -> EntityEvent_AbilityUseCanceled:
		return __ability_use_canceled.value
	func clear_ability_use_canceled() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ability_use_canceled() -> EntityEvent_AbilityUseCanceled:
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = EntityEvent_AbilityUseCanceled.new()
		return __ability_use_canceled.value

	var __ability_use_completed: PBField
	func has_ability_use_completed() -> bool:
		if __ability_use_completed.value != null:
			return true
		return false
	func get_ability_use_completed() -> EntityEvent_AbilityUseCompleted:
		return __ability_use_completed.value
	func clear_ability_use_completed() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ability_use_completed() -> EntityEvent_AbilityUseCompleted:
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = EntityEvent_AbilityUseCompleted.new()
		return __ability_use_completed.value

	var __damage_taken: PBField
	func has_damage_taken() -> bool:
		if __damage_taken.value != null:
			return true
		return false
	func get_damage_taken() -> EntityEvent_DamageTaken:
		return __damage_taken.value
	func clear_damage_taken() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_damage_taken() -> EntityEvent_DamageTaken:
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = EntityEvent_DamageTaken.new()
		return __damage_taken.value

	var __healing_received: PBField
	func has_healing_received() -> bool:
		if __healing_received.value != null:
			return true
		return false
	func get_healing_received() -> EntityEvent_HealingReceived:
		return __healing_received.value
	func clear_healing_received() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_healing_received() -> EntityEvent_HealingReceived:
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = EntityEvent_HealingReceived.new()
		return __healing_received.value

	var __buff_applied: PBField
	func has_buff_applied() -> bool:
		if __buff_applied.value != null:
			return true
		return false
	func get_buff_applied() -> EntityEvent_BuffApplied:
		return __buff_applied.value
	func clear_buff_applied() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_buff_applied() -> EntityEvent_BuffApplied:
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = EntityEvent_BuffApplied.new()
		return __buff_applied.value

	var __debuff_applied: PBField
	func has_debuff_applied() -> bool:
		if __debuff_applied.value != null:
			return true
		return false
	func get_debuff_applied() -> EntityEvent_DebuffApplied:
		return __debuff_applied.value
	func clear_debuff_applied() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_debuff_applied() -> EntityEvent_DebuffApplied:
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		data[8].state = PB_SERVICE_STATE.FILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = EntityEvent_DebuffApplied.new()
		return __debuff_applied.value

	var __status_effect_removed: PBField
	func has_status_effect_removed() -> bool:
		if __status_effect_removed.value != null:
			return true
		return false
	func get_status_effect_removed() -> EntityEvent_StatusEffectRemoved:
		return __status_effect_removed.value
	func clear_status_effect_removed() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_status_effect_removed() -> EntityEvent_StatusEffectRemoved:
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		data[9].state = PB_SERVICE_STATE.FILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = EntityEvent_StatusEffectRemoved.new()
		return __status_effect_removed.value

	var __combatant_died: PBField
	func has_combatant_died() -> bool:
		if __combatant_died.value != null:
			return true
		return false
	func get_combatant_died() -> EntityEvent_CombatantDied:
		return __combatant_died.value
	func clear_combatant_died() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_combatant_died() -> EntityEvent_CombatantDied:
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		data[10].state = PB_SERVICE_STATE.FILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = EntityEvent_CombatantDied.new()
		return __combatant_died.value

	var __combat_started: PBField
	func has_combat_started() -> bool:
		if __combat_started.value != null:
			return true
		return false
	func get_combat_started() -> EntityEvent_CombatStarted:
		return __combat_started.value
	func clear_combat_started() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_combat_started() -> EntityEvent_CombatStarted:
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		data[11].state = PB_SERVICE_STATE.FILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = EntityEvent_CombatStarted.new()
		return __combat_started.value

	var __combat_ended: PBField
	func has_combat_ended() -> bool:
		if __combat_ended.value != null:
			return true
		return false
	func get_combat_ended() -> EntityEvent_CombatEnded:
		return __combat_ended.value
	func clear_combat_ended() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__combat_ended.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_combat_ended() -> EntityEvent_CombatEnded:
		__ability_use_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_canceled.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__ability_use_completed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__damage_taken.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__healing_received.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__buff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__debuff_applied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__status_effect_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__combatant_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__combat_started.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		data[12].state = PB_SERVICE_STATE.FILLED
		__combat_ended.value = EntityEvent_CombatEnded.new()
		return __combat_ended.value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class StatusEffectState:
	func _init():
		var service

		__status_id = PBField.new("status_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __status_id
		data[__status_id.tag] = service

		__source_entity_id = PBField.new("source_entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __source_entity_id
		data[__source_entity_id.tag] = service

		__stacks = PBField.new("stacks", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __stacks
		data[__stacks.tag] = service

		__remaining_duration = PBField.new("remaining_duration", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __remaining_duration
		data[__remaining_duration.tag] = service

	var data = {}

	var __status_id: PBField
	func has_status_id() -> bool:
		if __status_id.value != null:
			return true
		return false
	func get_status_id() -> String:
		return __status_id.value
	func clear_status_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__status_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_status_id(value : String) -> void:
		__status_id.value = value

	var __source_entity_id: PBField
	func has_source_entity_id() -> bool:
		if __source_entity_id.value != null:
			return true
		return false
	func get_source_entity_id() -> int:
		return __source_entity_id.value
	func clear_source_entity_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__source_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_source_entity_id(value : int) -> void:
		__source_entity_id.value = value

	var __stacks: PBField
	func has_stacks() -> bool:
		if __stacks.value != null:
			return true
		return false
	func get_stacks() -> int:
		return __stacks.value
	func clear_stacks() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__stacks.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_stacks(value : int) -> void:
		__stacks.value = value

	var __remaining_duration: PBField
	func has_remaining_duration() -> bool:
		if __remaining_duration.value != null:
			return true
		return false
	func get_remaining_duration() -> float:
		return __remaining_duration.value
	func clear_remaining_duration() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__remaining_duration.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_remaining_duration(value : float) -> void:
		__remaining_duration.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class PlayerInput:
	func _init():
		var service

		__input_x = PBField.new("input_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __input_x
		data[__input_x.tag] = service

		__input_z = PBField.new("input_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __input_z
		data[__input_z.tag] = service

		__jump_pressed = PBField.new("jump_pressed", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __jump_pressed
		data[__jump_pressed.tag] = service

		__tick = PBField.new("tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service

		__rot_y = PBField.new("rot_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __rot_y
		data[__rot_y.tag] = service

		__ability_input = PBField.new("ability_input", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __ability_input
		service.func_ref = Callable(self, "new_ability_input")
		data[__ability_input.tag] = service

	var data = {}

	var __input_x: PBField
	func has_input_x() -> bool:
		if __input_x.value != null:
			return true
		return false
	func get_input_x() -> float:
		return __input_x.value
	func clear_input_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__input_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_input_x(value : float) -> void:
		__input_x.value = value

	var __input_z: PBField
	func has_input_z() -> bool:
		if __input_z.value != null:
			return true
		return false
	func get_input_z() -> float:
		return __input_z.value
	func clear_input_z() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__input_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_input_z(value : float) -> void:
		__input_z.value = value

	var __jump_pressed: PBField
	func has_jump_pressed() -> bool:
		if __jump_pressed.value != null:
			return true
		return false
	func get_jump_pressed() -> bool:
		return __jump_pressed.value
	func clear_jump_pressed() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__jump_pressed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_jump_pressed(value : bool) -> void:
		__jump_pressed.value = value

	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_tick(value : int) -> void:
		__tick.value = value

	var __rot_y: PBField
	func has_rot_y() -> bool:
		if __rot_y.value != null:
			return true
		return false
	func get_rot_y() -> float:
		return __rot_y.value
	func clear_rot_y() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__rot_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_rot_y(value : float) -> void:
		__rot_y.value = value

	var __ability_input: PBField
	func has_ability_input() -> bool:
		if __ability_input.value != null:
			return true
		return false
	func get_ability_input() -> AbilityInput:
		return __ability_input.value
	func clear_ability_input() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__ability_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ability_input() -> AbilityInput:
		__ability_input.value = AbilityInput.new()
		return __ability_input.value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityPosition:
	func _init():
		var service

		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service

		__pos_x = PBField.new("pos_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_x
		data[__pos_x.tag] = service

		__pos_y = PBField.new("pos_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_y
		data[__pos_y.tag] = service

		__pos_z = PBField.new("pos_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_z
		data[__pos_z.tag] = service

		__vel_x = PBField.new("vel_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_x
		data[__vel_x.tag] = service

		__vel_y = PBField.new("vel_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_y
		data[__vel_y.tag] = service

		__vel_z = PBField.new("vel_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_z
		data[__vel_z.tag] = service

		__rot_y = PBField.new("rot_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __rot_y
		data[__rot_y.tag] = service

		__active_impulse = PBField.new("active_impulse", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __active_impulse
		service.func_ref = Callable(self, "new_active_impulse")
		data[__active_impulse.tag] = service

		__is_on_floor = PBField.new("is_on_floor", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_on_floor
		data[__is_on_floor.tag] = service

	var data = {}

	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> int:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_entity_id(value : int) -> void:
		__entity_id.value = value

	var __pos_x: PBField
	func has_pos_x() -> bool:
		if __pos_x.value != null:
			return true
		return false
	func get_pos_x() -> float:
		return __pos_x.value
	func clear_pos_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__pos_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_x(value : float) -> void:
		__pos_x.value = value

	var __pos_y: PBField
	func has_pos_y() -> bool:
		if __pos_y.value != null:
			return true
		return false
	func get_pos_y() -> float:
		return __pos_y.value
	func clear_pos_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__pos_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_y(value : float) -> void:
		__pos_y.value = value

	var __pos_z: PBField
	func has_pos_z() -> bool:
		if __pos_z.value != null:
			return true
		return false
	func get_pos_z() -> float:
		return __pos_z.value
	func clear_pos_z() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__pos_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_z(value : float) -> void:
		__pos_z.value = value

	var __vel_x: PBField
	func has_vel_x() -> bool:
		if __vel_x.value != null:
			return true
		return false
	func get_vel_x() -> float:
		return __vel_x.value
	func clear_vel_x() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__vel_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_x(value : float) -> void:
		__vel_x.value = value

	var __vel_y: PBField
	func has_vel_y() -> bool:
		if __vel_y.value != null:
			return true
		return false
	func get_vel_y() -> float:
		return __vel_y.value
	func clear_vel_y() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__vel_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_y(value : float) -> void:
		__vel_y.value = value

	var __vel_z: PBField
	func has_vel_z() -> bool:
		if __vel_z.value != null:
			return true
		return false
	func get_vel_z() -> float:
		return __vel_z.value
	func clear_vel_z() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__vel_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_z(value : float) -> void:
		__vel_z.value = value

	var __rot_y: PBField
	func has_rot_y() -> bool:
		if __rot_y.value != null:
			return true
		return false
	func get_rot_y() -> float:
		return __rot_y.value
	func clear_rot_y() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__rot_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_rot_y(value : float) -> void:
		__rot_y.value = value

	var __active_impulse: PBField
	func has_active_impulse() -> bool:
		if __active_impulse.value != null:
			return true
		return false
	func get_active_impulse() -> Impulse:
		return __active_impulse.value
	func clear_active_impulse() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__active_impulse.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_active_impulse() -> Impulse:
		__active_impulse.value = Impulse.new()
		return __active_impulse.value

	var __is_on_floor: PBField
	func has_is_on_floor() -> bool:
		if __is_on_floor.value != null:
			return true
		return false
	func get_is_on_floor() -> bool:
		return __is_on_floor.value
	func clear_is_on_floor() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__is_on_floor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_on_floor(value : bool) -> void:
		__is_on_floor.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class WorldPositions:
	func _init():
		var service

		__tick = PBField.new("tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service

		var __entities_default: Array[EntityPosition] = []
		__entities = PBField.new("entities", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __entities_default)
		service = PBServiceField.new()
		service.field = __entities
		service.func_ref = Callable(self, "add_entities")
		data[__entities.tag] = service

	var data = {}

	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_tick(value : int) -> void:
		__tick.value = value

	var __entities: PBField
	func get_entities() -> Array[EntityPosition]:
		return __entities.value
	func clear_entities() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__entities.value.clear()
	func add_entities() -> EntityPosition:
		var element = EntityPosition.new()
		__entities.value.append(element)
		return element

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class EntityState:
	func _init():
		var service

		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service

		__hp = PBField.new("hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __hp
		data[__hp.tag] = service

		__max_hp = PBField.new("max_hp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_hp
		data[__max_hp.tag] = service

		__mana = PBField.new("mana", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __mana
		data[__mana.tag] = service

		__max_mana = PBField.new("max_mana", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_mana
		data[__max_mana.tag] = service

		__stamina = PBField.new("stamina", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __stamina
		data[__stamina.tag] = service

		__max_stamina = PBField.new("max_stamina", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_stamina
		data[__max_stamina.tag] = service

	var data = {}

	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> int:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_entity_id(value : int) -> void:
		__entity_id.value = value

	var __hp: PBField
	func has_hp() -> bool:
		if __hp.value != null:
			return true
		return false
	func get_hp() -> int:
		return __hp.value
	func clear_hp() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_hp(value : int) -> void:
		__hp.value = value

	var __max_hp: PBField
	func has_max_hp() -> bool:
		if __max_hp.value != null:
			return true
		return false
	func get_max_hp() -> int:
		return __max_hp.value
	func clear_max_hp() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__max_hp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_hp(value : int) -> void:
		__max_hp.value = value

	var __mana: PBField
	func has_mana() -> bool:
		if __mana.value != null:
			return true
		return false
	func get_mana() -> int:
		return __mana.value
	func clear_mana() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__mana.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_mana(value : int) -> void:
		__mana.value = value

	var __max_mana: PBField
	func has_max_mana() -> bool:
		if __max_mana.value != null:
			return true
		return false
	func get_max_mana() -> int:
		return __max_mana.value
	func clear_max_mana() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__max_mana.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_mana(value : int) -> void:
		__max_mana.value = value

	var __stamina: PBField
	func has_stamina() -> bool:
		if __stamina.value != null:
			return true
		return false
	func get_stamina() -> int:
		return __stamina.value
	func clear_stamina() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__stamina.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_stamina(value : int) -> void:
		__stamina.value = value

	var __max_stamina: PBField
	func has_max_stamina() -> bool:
		if __max_stamina.value != null:
			return true
		return false
	func get_max_stamina() -> int:
		return __max_stamina.value
	func clear_max_stamina() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__max_stamina.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_stamina(value : int) -> void:
		__max_stamina.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class WorldState:
	func _init():
		var service

		__tick = PBField.new("tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __tick
		data[__tick.tag] = service

		var __entities_default: Array[EntityState] = []
		__entities = PBField.new("entities", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __entities_default)
		service = PBServiceField.new()
		service.field = __entities
		service.func_ref = Callable(self, "add_entities")
		data[__entities.tag] = service

		var __events_default: Array[EntityEvent] = []
		__events = PBField.new("events", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 3, true, __events_default)
		service = PBServiceField.new()
		service.field = __events
		service.func_ref = Callable(self, "add_events")
		data[__events.tag] = service

	var data = {}

	var __tick: PBField
	func has_tick() -> bool:
		if __tick.value != null:
			return true
		return false
	func get_tick() -> int:
		return __tick.value
	func clear_tick() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_tick(value : int) -> void:
		__tick.value = value

	var __entities: PBField
	func get_entities() -> Array[EntityState]:
		return __entities.value
	func clear_entities() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__entities.value.clear()
	func add_entities() -> EntityState:
		var element = EntityState.new()
		__entities.value.append(element)
		return element

	var __events: PBField
	func get_events() -> Array[EntityEvent]:
		return __events.value
	func clear_events() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__events.value.clear()
	func add_events() -> EntityEvent:
		var element = EntityEvent.new()
		__events.value.append(element)
		return element

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class ClockPing:
	func _init():
		var service

		__ping_id = PBField.new("ping_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __ping_id
		data[__ping_id.tag] = service

		__client_time = PBField.new("client_time", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __client_time
		data[__client_time.tag] = service

	var data = {}

	var __ping_id: PBField
	func has_ping_id() -> bool:
		if __ping_id.value != null:
			return true
		return false
	func get_ping_id() -> int:
		return __ping_id.value
	func clear_ping_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ping_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_ping_id(value : int) -> void:
		__ping_id.value = value

	var __client_time: PBField
	func has_client_time() -> bool:
		if __client_time.value != null:
			return true
		return false
	func get_client_time() -> float:
		return __client_time.value
	func clear_client_time() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__client_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_client_time(value : float) -> void:
		__client_time.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class ClockPong:
	func _init():
		var service

		__ping_id = PBField.new("ping_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __ping_id
		data[__ping_id.tag] = service

		__client_time = PBField.new("client_time", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __client_time
		data[__client_time.tag] = service

		__server_time = PBField.new("server_time", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __server_time
		data[__server_time.tag] = service

		__server_tick = PBField.new("server_tick", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __server_tick
		data[__server_tick.tag] = service

	var data = {}

	var __ping_id: PBField
	func has_ping_id() -> bool:
		if __ping_id.value != null:
			return true
		return false
	func get_ping_id() -> int:
		return __ping_id.value
	func clear_ping_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ping_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_ping_id(value : int) -> void:
		__ping_id.value = value

	var __client_time: PBField
	func has_client_time() -> bool:
		if __client_time.value != null:
			return true
		return false
	func get_client_time() -> float:
		return __client_time.value
	func clear_client_time() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__client_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_client_time(value : float) -> void:
		__client_time.value = value

	var __server_time: PBField
	func has_server_time() -> bool:
		if __server_time.value != null:
			return true
		return false
	func get_server_time() -> float:
		return __server_time.value
	func clear_server_time() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__server_time.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_server_time(value : float) -> void:
		__server_time.value = value

	var __server_tick: PBField
	func has_server_tick() -> bool:
		if __server_tick.value != null:
			return true
		return false
	func get_server_tick() -> int:
		return __server_tick.value
	func clear_server_tick() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_server_tick(value : int) -> void:
		__server_tick.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class InputBatch:
	func _init():
		var service

		var __inputs_default: Array[PlayerInput] = []
		__inputs = PBField.new("inputs", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, __inputs_default)
		service = PBServiceField.new()
		service.field = __inputs
		service.func_ref = Callable(self, "add_inputs")
		data[__inputs.tag] = service

	var data = {}

	var __inputs: PBField
	func get_inputs() -> Array[PlayerInput]:
		return __inputs.value
	func clear_inputs() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__inputs.value.clear()
	func add_inputs() -> PlayerInput:
		var element = PlayerInput.new()
		__inputs.value.append(element)
		return element

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class ZoneRedirect:
	func _init():
		var service

		__zone_id = PBField.new("zone_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __zone_id
		data[__zone_id.tag] = service

		__address = PBField.new("address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __address
		data[__address.tag] = service

		__port = PBField.new("port", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __port
		data[__port.tag] = service

		__transfer_token = PBField.new("transfer_token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __transfer_token
		data[__transfer_token.tag] = service

	var data = {}

	var __zone_id: PBField
	func has_zone_id() -> bool:
		if __zone_id.value != null:
			return true
		return false
	func get_zone_id() -> String:
		return __zone_id.value
	func clear_zone_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_zone_id(value : String) -> void:
		__zone_id.value = value

	var __address: PBField
	func has_address() -> bool:
		if __address.value != null:
			return true
		return false
	func get_address() -> String:
		return __address.value
	func clear_address() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_address(value : String) -> void:
		__address.value = value

	var __port: PBField
	func has_port() -> bool:
		if __port.value != null:
			return true
		return false
	func get_port() -> int:
		return __port.value
	func clear_port() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__port.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_port(value : int) -> void:
		__port.value = value

	var __transfer_token: PBField
	func has_transfer_token() -> bool:
		if __transfer_token.value != null:
			return true
		return false
	func get_transfer_token() -> String:
		return __transfer_token.value
	func clear_transfer_token() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__transfer_token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_transfer_token(value : String) -> void:
		__transfer_token.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class ZoneArrival:
	func _init():
		var service

		__transfer_token = PBField.new("transfer_token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __transfer_token
		data[__transfer_token.tag] = service

	var data = {}

	var __transfer_token: PBField
	func has_transfer_token() -> bool:
		if __transfer_token.value != null:
			return true
		return false
	func get_transfer_token() -> String:
		return __transfer_token.value
	func clear_transfer_token() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__transfer_token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_transfer_token(value : String) -> void:
		__transfer_token.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class LoginRequest:
	func _init():
		var service

		__username = PBField.new("username", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __username
		data[__username.tag] = service

	var data = {}

	var __username: PBField
	func has_username() -> bool:
		if __username.value != null:
			return true
		return false
	func get_username() -> String:
		return __username.value
	func clear_username() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__username.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_username(value : String) -> void:
		__username.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class PlayerSpawn:
	func _init():
		var service

		__pos_x = PBField.new("pos_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_x
		data[__pos_x.tag] = service

		__pos_y = PBField.new("pos_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_y
		data[__pos_y.tag] = service

		__pos_z = PBField.new("pos_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_z
		data[__pos_z.tag] = service

		__rot_y = PBField.new("rot_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __rot_y
		data[__rot_y.tag] = service

	var data = {}

	var __pos_x: PBField
	func has_pos_x() -> bool:
		if __pos_x.value != null:
			return true
		return false
	func get_pos_x() -> float:
		return __pos_x.value
	func clear_pos_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__pos_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_x(value : float) -> void:
		__pos_x.value = value

	var __pos_y: PBField
	func has_pos_y() -> bool:
		if __pos_y.value != null:
			return true
		return false
	func get_pos_y() -> float:
		return __pos_y.value
	func clear_pos_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__pos_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_y(value : float) -> void:
		__pos_y.value = value

	var __pos_z: PBField
	func has_pos_z() -> bool:
		if __pos_z.value != null:
			return true
		return false
	func get_pos_z() -> float:
		return __pos_z.value
	func clear_pos_z() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__pos_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_z(value : float) -> void:
		__pos_z.value = value

	var __rot_y: PBField
	func has_rot_y() -> bool:
		if __rot_y.value != null:
			return true
		return false
	func get_rot_y() -> float:
		return __rot_y.value
	func clear_rot_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__rot_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_rot_y(value : float) -> void:
		__rot_y.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class PlayerState:
	func _init():
		var service

		__pos_x = PBField.new("pos_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_x
		data[__pos_x.tag] = service

		__pos_y = PBField.new("pos_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_y
		data[__pos_y.tag] = service

		__pos_z = PBField.new("pos_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __pos_z
		data[__pos_z.tag] = service

		__vel_x = PBField.new("vel_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_x
		data[__vel_x.tag] = service

		__vel_y = PBField.new("vel_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_y
		data[__vel_y.tag] = service

		__vel_z = PBField.new("vel_z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __vel_z
		data[__vel_z.tag] = service

		__rot_y = PBField.new("rot_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __rot_y
		data[__rot_y.tag] = service

	var data = {}

	var __pos_x: PBField
	func has_pos_x() -> bool:
		if __pos_x.value != null:
			return true
		return false
	func get_pos_x() -> float:
		return __pos_x.value
	func clear_pos_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__pos_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_x(value : float) -> void:
		__pos_x.value = value

	var __pos_y: PBField
	func has_pos_y() -> bool:
		if __pos_y.value != null:
			return true
		return false
	func get_pos_y() -> float:
		return __pos_y.value
	func clear_pos_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__pos_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_y(value : float) -> void:
		__pos_y.value = value

	var __pos_z: PBField
	func has_pos_z() -> bool:
		if __pos_z.value != null:
			return true
		return false
	func get_pos_z() -> float:
		return __pos_z.value
	func clear_pos_z() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__pos_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_pos_z(value : float) -> void:
		__pos_z.value = value

	var __vel_x: PBField
	func has_vel_x() -> bool:
		if __vel_x.value != null:
			return true
		return false
	func get_vel_x() -> float:
		return __vel_x.value
	func clear_vel_x() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__vel_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_x(value : float) -> void:
		__vel_x.value = value

	var __vel_y: PBField
	func has_vel_y() -> bool:
		if __vel_y.value != null:
			return true
		return false
	func get_vel_y() -> float:
		return __vel_y.value
	func clear_vel_y() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__vel_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_y(value : float) -> void:
		__vel_y.value = value

	var __vel_z: PBField
	func has_vel_z() -> bool:
		if __vel_z.value != null:
			return true
		return false
	func get_vel_z() -> float:
		return __vel_z.value
	func clear_vel_z() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__vel_z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_vel_z(value : float) -> void:
		__vel_z.value = value

	var __rot_y: PBField
	func has_rot_y() -> bool:
		if __rot_y.value != null:
			return true
		return false
	func get_rot_y() -> float:
		return __rot_y.value
	func clear_rot_y() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__rot_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_rot_y(value : float) -> void:
		__rot_y.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class ZoneRegister:
	func _init():
		var service

		__zone_id = PBField.new("zone_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __zone_id
		data[__zone_id.tag] = service

		__address = PBField.new("address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __address
		data[__address.tag] = service

		__port = PBField.new("port", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __port
		data[__port.tag] = service

		__max_players = PBField.new("max_players", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __max_players
		data[__max_players.tag] = service

		__current_players = PBField.new("current_players", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __current_players
		data[__current_players.tag] = service

	var data = {}

	var __zone_id: PBField
	func has_zone_id() -> bool:
		if __zone_id.value != null:
			return true
		return false
	func get_zone_id() -> String:
		return __zone_id.value
	func clear_zone_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_zone_id(value : String) -> void:
		__zone_id.value = value

	var __address: PBField
	func has_address() -> bool:
		if __address.value != null:
			return true
		return false
	func get_address() -> String:
		return __address.value
	func clear_address() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_address(value : String) -> void:
		__address.value = value

	var __port: PBField
	func has_port() -> bool:
		if __port.value != null:
			return true
		return false
	func get_port() -> int:
		return __port.value
	func clear_port() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__port.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_port(value : int) -> void:
		__port.value = value

	var __max_players: PBField
	func has_max_players() -> bool:
		if __max_players.value != null:
			return true
		return false
	func get_max_players() -> int:
		return __max_players.value
	func clear_max_players() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__max_players.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_max_players(value : int) -> void:
		__max_players.value = value

	var __current_players: PBField
	func has_current_players() -> bool:
		if __current_players.value != null:
			return true
		return false
	func get_current_players() -> int:
		return __current_players.value
	func clear_current_players() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__current_players.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_current_players(value : int) -> void:
		__current_players.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class ZoneTransferRequest:
	func _init():
		var service

		__peer_id = PBField.new("peer_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __peer_id
		data[__peer_id.tag] = service

		__from_zone_id = PBField.new("from_zone_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __from_zone_id
		data[__from_zone_id.tag] = service

		__to_zone_id = PBField.new("to_zone_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __to_zone_id
		data[__to_zone_id.tag] = service

		__player_state = PBField.new("player_state", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_state
		service.func_ref = Callable(self, "new_player_state")
		data[__player_state.tag] = service

		__entry_spawn_path = PBField.new("entry_spawn_path", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __entry_spawn_path
		data[__entry_spawn_path.tag] = service

	var data = {}

	var __peer_id: PBField
	func has_peer_id() -> bool:
		if __peer_id.value != null:
			return true
		return false
	func get_peer_id() -> int:
		return __peer_id.value
	func clear_peer_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__peer_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_peer_id(value : int) -> void:
		__peer_id.value = value

	var __from_zone_id: PBField
	func has_from_zone_id() -> bool:
		if __from_zone_id.value != null:
			return true
		return false
	func get_from_zone_id() -> String:
		return __from_zone_id.value
	func clear_from_zone_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__from_zone_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_from_zone_id(value : String) -> void:
		__from_zone_id.value = value

	var __to_zone_id: PBField
	func has_to_zone_id() -> bool:
		if __to_zone_id.value != null:
			return true
		return false
	func get_to_zone_id() -> String:
		return __to_zone_id.value
	func clear_to_zone_id() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__to_zone_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_to_zone_id(value : String) -> void:
		__to_zone_id.value = value

	var __player_state: PBField
	func has_player_state() -> bool:
		if __player_state.value != null:
			return true
		return false
	func get_player_state() -> PlayerState:
		return __player_state.value
	func clear_player_state() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__player_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_state() -> PlayerState:
		__player_state.value = PlayerState.new()
		return __player_state.value

	var __entry_spawn_path: PBField
	func has_entry_spawn_path() -> bool:
		if __entry_spawn_path.value != null:
			return true
		return false
	func get_entry_spawn_path() -> String:
		return __entry_spawn_path.value
	func clear_entry_spawn_path() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__entry_spawn_path.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_entry_spawn_path(value : String) -> void:
		__entry_spawn_path.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class PreparePlayer:
	func _init():
		var service

		__transfer_token = PBField.new("transfer_token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __transfer_token
		data[__transfer_token.tag] = service

		__player_state = PBField.new("player_state", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_state
		service.func_ref = Callable(self, "new_player_state")
		data[__player_state.tag] = service

		__entry_spawn_path = PBField.new("entry_spawn_path", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __entry_spawn_path
		data[__entry_spawn_path.tag] = service

	var data = {}

	var __transfer_token: PBField
	func has_transfer_token() -> bool:
		if __transfer_token.value != null:
			return true
		return false
	func get_transfer_token() -> String:
		return __transfer_token.value
	func clear_transfer_token() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__transfer_token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_transfer_token(value : String) -> void:
		__transfer_token.value = value

	var __player_state: PBField
	func has_player_state() -> bool:
		if __player_state.value != null:
			return true
		return false
	func get_player_state() -> PlayerState:
		return __player_state.value
	func clear_player_state() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_state() -> PlayerState:
		__player_state.value = PlayerState.new()
		return __player_state.value

	var __entry_spawn_path: PBField
	func has_entry_spawn_path() -> bool:
		if __entry_spawn_path.value != null:
			return true
		return false
	func get_entry_spawn_path() -> String:
		return __entry_spawn_path.value
	func clear_entry_spawn_path() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__entry_spawn_path.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_entry_spawn_path(value : String) -> void:
		__entry_spawn_path.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class PreparePlayerAck:
	func _init():
		var service

		__transfer_token = PBField.new("transfer_token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __transfer_token
		data[__transfer_token.tag] = service

		__accepted = PBField.new("accepted", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __accepted
		data[__accepted.tag] = service

	var data = {}

	var __transfer_token: PBField
	func has_transfer_token() -> bool:
		if __transfer_token.value != null:
			return true
		return false
	func get_transfer_token() -> String:
		return __transfer_token.value
	func clear_transfer_token() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__transfer_token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_transfer_token(value : String) -> void:
		__transfer_token.value = value

	var __accepted: PBField
	func has_accepted() -> bool:
		if __accepted.value != null:
			return true
		return false
	func get_accepted() -> bool:
		return __accepted.value
	func clear_accepted() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_accepted(value : bool) -> void:
		__accepted.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class ZoneTransferResponse:
	func _init():
		var service

		__peer_id = PBField.new("peer_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __peer_id
		data[__peer_id.tag] = service

		__transfer_token = PBField.new("transfer_token", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __transfer_token
		data[__transfer_token.tag] = service

		__target_address = PBField.new("target_address", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __target_address
		data[__target_address.tag] = service

		__target_port = PBField.new("target_port", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __target_port
		data[__target_port.tag] = service

		__zone_id = PBField.new("zone_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __zone_id
		data[__zone_id.tag] = service

	var data = {}

	var __peer_id: PBField
	func has_peer_id() -> bool:
		if __peer_id.value != null:
			return true
		return false
	func get_peer_id() -> int:
		return __peer_id.value
	func clear_peer_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__peer_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_peer_id(value : int) -> void:
		__peer_id.value = value

	var __transfer_token: PBField
	func has_transfer_token() -> bool:
		if __transfer_token.value != null:
			return true
		return false
	func get_transfer_token() -> String:
		return __transfer_token.value
	func clear_transfer_token() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__transfer_token.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_transfer_token(value : String) -> void:
		__transfer_token.value = value

	var __target_address: PBField
	func has_target_address() -> bool:
		if __target_address.value != null:
			return true
		return false
	func get_target_address() -> String:
		return __target_address.value
	func clear_target_address() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__target_address.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_target_address(value : String) -> void:
		__target_address.value = value

	var __target_port: PBField
	func has_target_port() -> bool:
		if __target_port.value != null:
			return true
		return false
	func get_target_port() -> int:
		return __target_port.value
	func clear_target_port() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__target_port.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_target_port(value : int) -> void:
		__target_port.value = value

	var __zone_id: PBField
	func has_zone_id() -> bool:
		if __zone_id.value != null:
			return true
		return false
	func get_zone_id() -> String:
		return __zone_id.value
	func clear_zone_id() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_zone_id(value : String) -> void:
		__zone_id.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class Packet:
	func _init():
		var service

		__player_input = PBField.new("player_input", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_input
		service.func_ref = Callable(self, "new_player_input")
		data[__player_input.tag] = service

		__world_positions = PBField.new("world_positions", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __world_positions
		service.func_ref = Callable(self, "new_world_positions")
		data[__world_positions.tag] = service

		__clock_ping = PBField.new("clock_ping", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __clock_ping
		service.func_ref = Callable(self, "new_clock_ping")
		data[__clock_ping.tag] = service

		__clock_pong = PBField.new("clock_pong", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __clock_pong
		service.func_ref = Callable(self, "new_clock_pong")
		data[__clock_pong.tag] = service

		__input_batch = PBField.new("input_batch", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __input_batch
		service.func_ref = Callable(self, "new_input_batch")
		data[__input_batch.tag] = service

		__zone_redirect = PBField.new("zone_redirect", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __zone_redirect
		service.func_ref = Callable(self, "new_zone_redirect")
		data[__zone_redirect.tag] = service

		__zone_arrival = PBField.new("zone_arrival", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __zone_arrival
		service.func_ref = Callable(self, "new_zone_arrival")
		data[__zone_arrival.tag] = service

		__login_request = PBField.new("login_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __login_request
		service.func_ref = Callable(self, "new_login_request")
		data[__login_request.tag] = service

		__player_spawn = PBField.new("player_spawn", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_spawn
		service.func_ref = Callable(self, "new_player_spawn")
		data[__player_spawn.tag] = service

		__target_select = PBField.new("target_select", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __target_select
		service.func_ref = Callable(self, "new_target_select")
		data[__target_select.tag] = service

		__ability_accepted = PBField.new("ability_accepted", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __ability_accepted
		service.func_ref = Callable(self, "new_ability_accepted")
		data[__ability_accepted.tag] = service

		__ability_rejected = PBField.new("ability_rejected", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __ability_rejected
		service.func_ref = Callable(self, "new_ability_rejected")
		data[__ability_rejected.tag] = service

		__world_state = PBField.new("world_state", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __world_state
		service.func_ref = Callable(self, "new_world_state")
		data[__world_state.tag] = service

		__ability_resolved = PBField.new("ability_resolved", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __ability_resolved
		service.func_ref = Callable(self, "new_ability_resolved")
		data[__ability_resolved.tag] = service

	var data = {}

	var __player_input: PBField
	func has_player_input() -> bool:
		if __player_input.value != null:
			return true
		return false
	func get_player_input() -> PlayerInput:
		return __player_input.value
	func clear_player_input() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_input() -> PlayerInput:
		data[1].state = PB_SERVICE_STATE.FILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__player_input.value = PlayerInput.new()
		return __player_input.value

	var __world_positions: PBField
	func has_world_positions() -> bool:
		if __world_positions.value != null:
			return true
		return false
	func get_world_positions() -> WorldPositions:
		return __world_positions.value
	func clear_world_positions() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_world_positions() -> WorldPositions:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		data[2].state = PB_SERVICE_STATE.FILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = WorldPositions.new()
		return __world_positions.value

	var __clock_ping: PBField
	func has_clock_ping() -> bool:
		if __clock_ping.value != null:
			return true
		return false
	func get_clock_ping() -> ClockPing:
		return __clock_ping.value
	func clear_clock_ping() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_clock_ping() -> ClockPing:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = ClockPing.new()
		return __clock_ping.value

	var __clock_pong: PBField
	func has_clock_pong() -> bool:
		if __clock_pong.value != null:
			return true
		return false
	func get_clock_pong() -> ClockPong:
		return __clock_pong.value
	func clear_clock_pong() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_clock_pong() -> ClockPong:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = ClockPong.new()
		return __clock_pong.value

	var __input_batch: PBField
	func has_input_batch() -> bool:
		if __input_batch.value != null:
			return true
		return false
	func get_input_batch() -> InputBatch:
		return __input_batch.value
	func clear_input_batch() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_input_batch() -> InputBatch:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = InputBatch.new()
		return __input_batch.value

	var __zone_redirect: PBField
	func has_zone_redirect() -> bool:
		if __zone_redirect.value != null:
			return true
		return false
	func get_zone_redirect() -> ZoneRedirect:
		return __zone_redirect.value
	func clear_zone_redirect() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_zone_redirect() -> ZoneRedirect:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = ZoneRedirect.new()
		return __zone_redirect.value

	var __zone_arrival: PBField
	func has_zone_arrival() -> bool:
		if __zone_arrival.value != null:
			return true
		return false
	func get_zone_arrival() -> ZoneArrival:
		return __zone_arrival.value
	func clear_zone_arrival() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_zone_arrival() -> ZoneArrival:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = ZoneArrival.new()
		return __zone_arrival.value

	var __login_request: PBField
	func has_login_request() -> bool:
		if __login_request.value != null:
			return true
		return false
	func get_login_request() -> LoginRequest:
		return __login_request.value
	func clear_login_request() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_login_request() -> LoginRequest:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		data[8].state = PB_SERVICE_STATE.FILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = LoginRequest.new()
		return __login_request.value

	var __player_spawn: PBField
	func has_player_spawn() -> bool:
		if __player_spawn.value != null:
			return true
		return false
	func get_player_spawn() -> PlayerSpawn:
		return __player_spawn.value
	func clear_player_spawn() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_spawn() -> PlayerSpawn:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		data[9].state = PB_SERVICE_STATE.FILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = PlayerSpawn.new()
		return __player_spawn.value

	var __target_select: PBField
	func has_target_select() -> bool:
		if __target_select.value != null:
			return true
		return false
	func get_target_select() -> TargetSelect:
		return __target_select.value
	func clear_target_select() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_target_select() -> TargetSelect:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		data[10].state = PB_SERVICE_STATE.FILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = TargetSelect.new()
		return __target_select.value

	var __ability_accepted: PBField
	func has_ability_accepted() -> bool:
		if __ability_accepted.value != null:
			return true
		return false
	func get_ability_accepted() -> AbilityUseAccepted:
		return __ability_accepted.value
	func clear_ability_accepted() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ability_accepted() -> AbilityUseAccepted:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		data[11].state = PB_SERVICE_STATE.FILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = AbilityUseAccepted.new()
		return __ability_accepted.value

	var __ability_rejected: PBField
	func has_ability_rejected() -> bool:
		if __ability_rejected.value != null:
			return true
		return false
	func get_ability_rejected() -> AbilityUseRejected:
		return __ability_rejected.value
	func clear_ability_rejected() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ability_rejected() -> AbilityUseRejected:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		data[12].state = PB_SERVICE_STATE.FILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = AbilityUseRejected.new()
		return __ability_rejected.value

	var __world_state: PBField
	func has_world_state() -> bool:
		if __world_state.value != null:
			return true
		return false
	func get_world_state() -> WorldState:
		return __world_state.value
	func clear_world_state() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_world_state() -> WorldState:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		data[13].state = PB_SERVICE_STATE.FILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = WorldState.new()
		return __world_state.value

	var __ability_resolved: PBField
	func has_ability_resolved() -> bool:
		if __ability_resolved.value != null:
			return true
		return false
	func get_ability_resolved() -> AbilityUseResolved:
		return __ability_resolved.value
	func clear_ability_resolved() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__ability_resolved.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ability_resolved() -> AbilityUseResolved:
		__player_input.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__world_positions.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__clock_ping.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__clock_pong.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__input_batch.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_redirect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__zone_arrival.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__player_spawn.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__target_select.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__ability_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__ability_rejected.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__world_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		data[14].state = PB_SERVICE_STATE.FILLED
		__ability_resolved.value = AbilityUseResolved.new()
		return __ability_resolved.value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class Heartbeat:
	func _init():
		var service

		__ping_id = PBField.new("ping_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __ping_id
		data[__ping_id.tag] = service

	var data = {}

	var __ping_id: PBField
	func has_ping_id() -> bool:
		if __ping_id.value != null:
			return true
		return false
	func get_ping_id() -> int:
		return __ping_id.value
	func clear_ping_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ping_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_ping_id(value : int) -> void:
		__ping_id.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class HeartbeatAck:
	func _init():
		var service

		__ping_id = PBField.new("ping_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = __ping_id
		data[__ping_id.tag] = service

	var data = {}

	var __ping_id: PBField
	func has_ping_id() -> bool:
		if __ping_id.value != null:
			return true
		return false
	func get_ping_id() -> int:
		return __ping_id.value
	func clear_ping_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__ping_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_ping_id(value : int) -> void:
		__ping_id.value = value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

class OrchestratorPacket:
	func _init():
		var service

		__zone_register = PBField.new("zone_register", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __zone_register
		service.func_ref = Callable(self, "new_zone_register")
		data[__zone_register.tag] = service

		__zone_transfer_request = PBField.new("zone_transfer_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __zone_transfer_request
		service.func_ref = Callable(self, "new_zone_transfer_request")
		data[__zone_transfer_request.tag] = service

		__prepare_player = PBField.new("prepare_player", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __prepare_player
		service.func_ref = Callable(self, "new_prepare_player")
		data[__prepare_player.tag] = service

		__prepare_player_ack = PBField.new("prepare_player_ack", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __prepare_player_ack
		service.func_ref = Callable(self, "new_prepare_player_ack")
		data[__prepare_player_ack.tag] = service

		__zone_transfer_response = PBField.new("zone_transfer_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __zone_transfer_response
		service.func_ref = Callable(self, "new_zone_transfer_response")
		data[__zone_transfer_response.tag] = service

		__heartbeat = PBField.new("heartbeat", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __heartbeat
		service.func_ref = Callable(self, "new_heartbeat")
		data[__heartbeat.tag] = service

		__heartbeat_ack = PBField.new("heartbeat_ack", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __heartbeat_ack
		service.func_ref = Callable(self, "new_heartbeat_ack")
		data[__heartbeat_ack.tag] = service

	var data = {}

	var __zone_register: PBField
	func has_zone_register() -> bool:
		if __zone_register.value != null:
			return true
		return false
	func get_zone_register() -> ZoneRegister:
		return __zone_register.value
	func clear_zone_register() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_zone_register() -> ZoneRegister:
		data[1].state = PB_SERVICE_STATE.FILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__zone_register.value = ZoneRegister.new()
		return __zone_register.value

	var __zone_transfer_request: PBField
	func has_zone_transfer_request() -> bool:
		if __zone_transfer_request.value != null:
			return true
		return false
	func get_zone_transfer_request() -> ZoneTransferRequest:
		return __zone_transfer_request.value
	func clear_zone_transfer_request() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_zone_transfer_request() -> ZoneTransferRequest:
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		data[2].state = PB_SERVICE_STATE.FILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = ZoneTransferRequest.new()
		return __zone_transfer_request.value

	var __prepare_player: PBField
	func has_prepare_player() -> bool:
		if __prepare_player.value != null:
			return true
		return false
	func get_prepare_player() -> PreparePlayer:
		return __prepare_player.value
	func clear_prepare_player() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_prepare_player() -> PreparePlayer:
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = PreparePlayer.new()
		return __prepare_player.value

	var __prepare_player_ack: PBField
	func has_prepare_player_ack() -> bool:
		if __prepare_player_ack.value != null:
			return true
		return false
	func get_prepare_player_ack() -> PreparePlayerAck:
		return __prepare_player_ack.value
	func clear_prepare_player_ack() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_prepare_player_ack() -> PreparePlayerAck:
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = PreparePlayerAck.new()
		return __prepare_player_ack.value

	var __zone_transfer_response: PBField
	func has_zone_transfer_response() -> bool:
		if __zone_transfer_response.value != null:
			return true
		return false
	func get_zone_transfer_response() -> ZoneTransferResponse:
		return __zone_transfer_response.value
	func clear_zone_transfer_response() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_zone_transfer_response() -> ZoneTransferResponse:
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = ZoneTransferResponse.new()
		return __zone_transfer_response.value

	var __heartbeat: PBField
	func has_heartbeat() -> bool:
		if __heartbeat.value != null:
			return true
		return false
	func get_heartbeat() -> Heartbeat:
		return __heartbeat.value
	func clear_heartbeat() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_heartbeat() -> Heartbeat:
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		__heartbeat_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = Heartbeat.new()
		return __heartbeat.value

	var __heartbeat_ack: PBField
	func has_heartbeat_ack() -> bool:
		if __heartbeat_ack.value != null:
			return true
		return false
	func get_heartbeat_ack() -> HeartbeatAck:
		return __heartbeat_ack.value
	func clear_heartbeat_ack() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_heartbeat_ack() -> HeartbeatAck:
		__zone_register.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__prepare_player_ack.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__zone_transfer_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		__heartbeat_ack.value = HeartbeatAck.new()
		return __heartbeat_ack.value

	func _to_string() -> String:
		return PBPacker.message_to_string(data)

	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)

	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result

################ USER DATA END #################
