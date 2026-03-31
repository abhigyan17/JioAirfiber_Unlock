# Use the official Microsoft Playwright image as the base
FROM mcr.microsoft.com/playwright:v1.50.1-jammy

# Set working directory inside the container
WORKDIR /app

# Copy package setup files first to leverage Docker layer caching
COPY package*.json ./

# Install Node dependencies (including Playwright npm libraries)
RUN npm install

# Copy all source files
COPY . .

# Expose the express GUI port
EXPOSE 3000

# Start the Node.js GUI server
CMD ["npm", "start"]
