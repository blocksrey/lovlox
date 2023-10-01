local socket = {}

function socket.tcp()
	print('tcp')

	local self = {}

	function self.settimeout()
		print('settimeout')
	end

	function self.connect()
		print('connect')
	end

	function self.send()
		print('send')
	end

	function self.receive()
		print('receive')
	end

	return self
end

function socket.bind()
	print('bind')

	local self = {}

	function self.settimeout()
		print('settimeout')
	end

	return self
end

return socket