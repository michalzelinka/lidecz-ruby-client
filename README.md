# Lide.cz Ruby client

Tiny Ruby library for fetching data from _Lide.cz_, popular czech social network. Basically built up by decomposing the JavaScript application on the website and porting its code parts to Ruby.

## Sample use

### Get configuration with token
`{:method=>"configuration.get", :params=>[]}`

### Get user profile
`{:method=>"profile.get", :params=>["YZ84mABTpsXWDvbL"]}`

### Get user's photos (profile ID, last photo ID, count)
`{:method=>"profile.get.photos", :params=>["YZ84mABTpsXWDvbL", nil, 5]}`

### Get events
`{:method=>"event.getNewItems", :params=>[nil, nil, nil]}`

### Get chat contact
`{:method=>"chat.getContact", :params=>["YZ84mABTpsXWDvbL"]}`

### Get chat history
`{:method=>"chat.history", :params=>["YZ84mABTpsXWDvbL"]}`