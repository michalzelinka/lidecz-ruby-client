require 'net/https'
require 'json'
require 'pp'


class RequestComposer

	def initialize(request, options, dummy = nil)
		chars = serializeCall(request, options, dummy)
		@request = Base64::btoa chars
	end

	def request
		@request
	end

	def serializeCall(a, b, c)
		b = serialize(b, c)
		b.shift
		b.shift
		a = encodeUTF8 a
		a.reverse_each{|i| b.unshift i }
		b.unshift a.count
		b.unshift 13<<3
		b.unshift 202, 17, 2, 0
		return b
	end

	def serialize(a, b)
		c = [ ]
		serializeValue(c, a)
		return c
	end

	def serializeValue(a, b)

		if b == nil then
			a.push 96 # FRPC.NULL (12) << 3
		else

			if b.is_a? Array then
				serializeArray(a, b)
			elsif b.is_a? String then
				c = encodeUTF8 b
				h = encodeInt c.count
				f = 32 # FRPC.STRING  (4) << 3
				f = f + (h.count - 1)
				a.push f
				append a, h
				append a, c
			elsif b.is_a? Integer then
				f = b > 0 ?  7 : 8 # FRPC_INT8P (or INT8N)
				f = f<<3
				c = encodeInt b.abs
				f += c.count - 1
				a.push f
				append a, c
			elsif b.is_a? Float then
				f = 3<<3 # FRPC_DOUBLE
				c = this._encodeDouble b
				a.push f
				append a, c
			end

		end

	end

	def serializeArray(a, b)
		c = 88 # FRPC.ARRAY << 3
		h = encodeInt b.count
		c += h.count - 1
		a.push c
		append(a, h)
		c = 0
		0.upto(b.count-1){|c|
			serializeValue a, b[c]
		}
	end

	def append(a, b)
		0.upto(b.count-1){|h|
			a.push b[h]
		}
	end

	def encodeInt(a)
		return [ 0 ] if !a
		b = [ ]
		while a > 0 do
			c = a % 256
			a = (a - c) / 256
			b.push c
		end
		return b
	end

	def encodeUTF8(a)
		b = [ ]
		0.upto(a.length-1){|i|
			h = a[i]
			b.push h.ord
		}
		return b
	end

end


class ResponseParser

	def initialize(responseText)
		chars = Base64::atob responseText
		@data = nil
		@pointer = 0
		@token = nil
		@response = self.parse chars
	end

	def response
		@response
	end

	def token
		@token
	end

	def parse(a)
		@data = a
		@pointer = 0
		a = getByte()
		b = getByte()
		getByte()
		getByte()
		a = getInt(1) >> 3
		b = nil

		if a == 14 then
			b = parseValue()
		elsif a == 13 then
	        a = decodeUTF8(getInt(1))
	        b = [ ]
	        while @pointer < @data.length do
	        	b.push parseValue()
	        end

	        @data = [ ]

	        return { method: a, params: b }
	    end

	    @data = [ ]

	    return b
	end

	def parseValue
		a = getInt(1)
		b = a >> 3

		# puts "Position #{@pointer} of #{@data.length}: node of type #{b}"

		case b
		when 1 # int
			a = a & 7
			c = 2 ** (8*a)
			b = getInt a
			b >= c / 2 && (b -= c)
			return b
		when 2 # bool
			return a & 1 ? !0 : !1
		when 3 # double
			return getDouble()
		when 4 # string
			a = getInt((a & 7) + 1)
			return decodeUTF8(a)
		when 5 # datetime
			return nil ##########
		when 6 # binary
			a = getInt((a & 7) + 1)
			b = [ ]
			(a-1).downto(0){|i| b.push getByte() }
			return b
		when 7 # int8p
			return getInt((a & 7) + 1)
		when 8 # int8n
			return -getInt((a & 7) + 1)
		when 10 # struct
			b = { }
			a = getInt((a & 7) + 1)
			(a-1).downto(0){|i| parseMember(b) }
			return b
		when 11 # array
			b = [ ]
			a = getInt((a & 7) + 1)
			(a-1).downto(0){|i| b.push parseValue() }
			return b
		when 12 # null
			return nil
		else
			# throw "FRPC data error: #{b}"
			getInt 1
		end
	end

	def parseMember(a)
		b = decodeUTF8(getInt(1))
		a[b] = parseValue()
		@token = a[b] if (b == 'csrf_token')
	end

	def decodeUTF8(a)
		b = a
		c = ""
		return c if !a
		h = 0
		a = 0
		f = 0
		d = @data
		g = @pointer

		while b > 0 do
			b -= 1
		    a = d[g]
		    g += 1
		    128 > a ?
			    c += a.chr(Encoding::UTF_8) :
			    191 < a && 224 > a ? (
				    h = d[g]
				    g += 1
				    c += ((a & 31)<<6 | h & 63).chr(Encoding::UTF_8)
				    b -= 1
				) :
				240 > a ? (
					h = d[g]
					g += 1
					f = d[g]
					g += 1
					c += ((a & 15)<<12 | (h & 63)<<6 | f & 63).chr(Encoding::UTF_8)
					b -= 2
				) :
				248 > a ? (
					g += 3
					b -= 3
				) :
				252 > a ? (
					g += 4
					b -= 4
				) :
				(
					g += 5
					b -= 5
				)
		end

		@pointer = g + b
		return c
	end

	def getByte
		b = @data[@pointer]
		@pointer += 1
		return b
	end

	def getInt(a)
		b = 0
		c = 1
		0.upto(a-1){|h| b += c * getByte(); c *= 256; }
		return b
	end

	def getDouble
		a = [ ]
		7.downto(0){|i| a[i] = getByte() }
	    c = a[0] & 128 ? 1 : 0
	    h = (a[0] & 127)<<4
	    h = h + (a[1]>>4)
	    return 0 * (-1 ** c) if (0 == h)
	    f = 0
	    e = 1
	    d = 3
	    b = 1
	    begin
	        f += (a[e] & 1<<d ? 1 : 0) * (2 ** - b)
	        b += 1
	        d -= 1
	        0 > d && (d = 7, e += 1)
	    end while (e < a.length)
	    return f ? nil : Float::INFINITY * (-1 ** c) if (2047 == h)
	    h -= 1023
	    return (-1 ** c) * (2 ** h) * (1 + f)
	end

end


class Base64

	@@alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
	@@indexedAlphabet = @@alphabet.split ""
	@@associatedAlphabet = { }

	0.upto(@@alphabet.length-1){|i| @@associatedAlphabet[@@alphabet[i]] = i }

	def self.atob(a)
		b = [ ]
		c = nil
		h = nil
		f = nil
		e = nil
		d = a.gsub(/\s/, "").split("")
		g = 0
		j = d.length
		while g < j do
	        c = @@associatedAlphabet[d[g]]
	        h = @@associatedAlphabet[d[g + 1]]
	        a = @@associatedAlphabet[d[g + 2]]
	        e = @@associatedAlphabet[d[g + 3]]
	        c = c<<2 | h>>4
	        h = (h & 15)<<4 | a>>2
	        f = (a & 3)<<6 | e
	        b.push(c)
	        64 != a && b.push(h)
	        64 != e && b.push(f)
			g += 4
		end

	    return b
	end

	def self.btoa(a)
	    b = [ ]
	    c = nil
	    h = nil
	    f = nil
	    e = nil
	    d = nil
	    g = nil
	    j = 0
	    k = a.length
	    begin

	        c = j < a.length ? a[(j+=1)-1] : nil
	        h = j < a.length ? a[(j+=1)-1] : nil
	        f = j < a.length ? a[(j+=1)-1] : nil
	        e = (c || 0) >> 2
	        c = ((c || 0) & 3) << 4 | (h || 0) >> 4
	        d = ((h || 0) & 15) << 2 | (f || 0) >> 6
	        g = (f || 0) & 63
	        (h == nil) ? d = g = 64 : (f == nil) && (g = 64)
	        b.push(@@indexedAlphabet[e])
	        b.push(@@indexedAlphabet[c])
	        b.push(@@indexedAlphabet[d])
	        b.push(@@indexedAlphabet[g])

	    end while (j < k)

	    return b.join("")
	end

end


class LideAPI

	@@token = nil
	@@cookie = nil

	def self.request(action, options)

		if @@token == nil && action != 'configuration.get'

			LideAPI.request('configuration.get', [ ])

		end

		requestBody = RequestComposer.new(action, options, nil).request

		uri = URI.parse("https://www.lide.cz/RPC2")
		https = Net::HTTP.new(uri.host,uri.port)
		https.use_ssl = true

		headers = {
			'Content-Type' => 'application/x-base64-frpc',
			# 'Accept' => 'application/x-base64-frpc',
			'Accept' => 'application/json',
			'Referer' => 'https://www.lide.cz/detail/LvEbLR4zUWDzeNNg',
			'User-Agent' => 'Mozilla/5.0 AppleWebKit/601.4.4 Safari/601.4.4',
			'Origin' => 'https://www.lide.cz/',
		}

		headers['X-Csrf-Token'] = @@token if @@token != nil

		req = Net::HTTP::Post.new(uri.path, initheader = headers)
		req.body = requestBody

		res = https.request(req)

		cookie = res['Set-Cookie']
		cookie = cookie[0..cookie.index(';')] if cookie
		cookie = nil if cookie && cookie.length < 10
		@@cookie = cookie if cookie != nil

		# puts "Response #{res.code} #{res.message}: #{res.body}"

=begin FRPC
		parser = ResponseParser.new(res.body)

		@@token = parser.token if parser.token != nil

		return parser.response
=end

		res = JSON.parse res.body

		@@token = res["csrf_token"] if res["csrf_token"] != nil

		return res

	end

end

=begin

Sample use:

# Get configuration with token
{:method=>"configuration.get", :params=>[]}

# Get user profile
{:method=>"profile.get", :params=>["YZ84mABTpsXWDvbL"]}

# Get user's photos
# profile ID, last photo ID, count
{:method=>"profile.get.photos", :params=>["YZ84mABTpsXWDvbL", nil, 5]}

# Get events
{:method=>"event.getNewItems", :params=>[nil, nil, nil]}

# Get chat contact
{:method=>"chat.getContact", :params=>["YZ84mABTpsXWDvbL"]}

# Get chat history
{:method=>"chat.history", :params=>["YZ84mABTpsXWDvbL"]}

=end
